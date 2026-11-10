import Foundation
import Combine
import CoreBluetooth

struct DiscoveredScooter: Identifiable, Equatable {
    let id: UUID
    let name: String
    var rssi: Int
    let peripheral: CBPeripheral

    static func == (a: DiscoveredScooter, b: DiscoveredScooter) -> Bool { a.id == b.id && a.rssi == b.rssi && a.name == b.name }
}

enum SessionState: Equatable {
    case idle
    case bluetoothOff
    case unauthorized
    case scanning
    case connecting
    case keyExchange
    case waitingForButton(secondsLeft: Int)
    case reading
    case done
    case failed(Failure)

    enum Failure: Equatable {
        case noButtonPress
        case encryptedUnreadable
        case noAnswer
        case noBatteryData
        case noCells
        case disconnected
        case serviceMissing
    }
}

/// Talks to Ninebot/Xiaomi-family scooters over the Nordic UART service.
/// Read-only: only READ and pairing commands are ever sent.
@MainActor
final class ScooterSession: NSObject, ObservableObject {
    @Published private(set) var state: SessionState = .idle
    @Published private(set) var scooters: [DiscoveredScooter] = []
    @Published private(set) var reading: BatteryReading?
    @Published private(set) var log: [String] = []
    @Published private(set) var connectedName: String?

    /// Created on first use, so the Bluetooth permission prompt appears when the user starts a scan.
    private lazy var central: CBCentralManager = CBCentralManager(delegate: self, queue: .main)
    private var peripheral: CBPeripheral?
    private var rxChar: CBCharacteristic?
    private var advertisedName = ""
    private var mode: WireMode = .encrypted
    private var crypto: NbCrypto?
    private var buffer: [UInt8] = []
    private var rawBytes = 0
    private final class Waiter {
        let id = UUID()
        let match: (Frame) -> Bool
        var result: Frame?
        var finished = false
        var cont: CheckedContinuation<Frame?, Never>?
        init(match: @escaping (Frame) -> Bool) { self.match = match }
        func finish(_ f: Frame?) {
            guard !finished else { return }
            if let c = cont { finished = true; cont = nil; c.resume(returning: f) } else { result = f; finished = true }
        }
    }
    private var waiters: [Waiter] = []
    private var connectContinuation: CheckedContinuation<Bool, Never>?
    private var notifyContinuation: CheckedContinuation<Bool, Never>?
    private var wantScan = false

    override init() {
        super.init()
    }

    private func timeout(_ seconds: Double, _ fire: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            fire()
        }
    }

    // MARK: Logging

    private func addLog(_ s: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        log.append("\(f.string(from: Date()))  \(s)")
        if log.count > 3000 { log.removeFirst(log.count - 3000) }
    }

    var logText: String { log.joined(separator: "\n") }

    // MARK: Scan

    func startScan() {
        scooters = []
        wantScan = true
        guard central.state == .poweredOn else { updateBluetoothState(); return }
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        addLog("Scan started")
    }

    func stopScan() {
        wantScan = false
        if central.isScanning { central.stopScan() }
        if state == .scanning { state = .idle }
    }

    private func updateBluetoothState() {
        switch central.state {
        case .poweredOff: state = .bluetoothOff
        case .unauthorized: state = .unauthorized
        case .poweredOn:
            if wantScan && state != .scanning { startScan() }
            else if state == .bluetoothOff || state == .unauthorized { state = .idle }
        default: break
        }
    }

    private func looksLikeScooter(name: String, services: [CBUUID]) -> Bool {
        if services.contains(NUS.service) { return true }
        let n = name.lowercased()
        return n.contains("scooter") || n.hasPrefix("nb") || n.hasPrefix("mi") || n.contains("ninebot") || n.contains("segway")
    }

    // MARK: Connect & measure

    func connectAndMeasure(_ scooter: DiscoveredScooter) {
        stopScan()
        Task { await run(scooter) }
    }

    func remeasure() {
        guard peripheral?.state == .connected else { return }
        Task { await measure() }
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    func forgetPairings() {
        PairingStore.removeAll()
        addLog("All stored pairings removed")
    }

    private func run(_ scooter: DiscoveredScooter) async {
        reading = nil
        rawBytes = 0
        advertisedName = scooter.name
        connectedName = scooter.name
        state = .connecting
        addLog("Connecting to \(scooter.name)")
        let p = scooter.peripheral
        peripheral = p
        p.delegate = self

        let connected: Bool = await withCheckedContinuation { c in
            connectContinuation = c
            central.connect(p, options: nil)
            timeout(15) { [weak self] in
                guard let self, let c = self.connectContinuation else { return }
                self.connectContinuation = nil
                self.central.cancelPeripheralConnection(p)
                self.addLog("Connect timeout")
                c.resume(returning: false)
            }
        }
        guard connected else { state = .failed(.disconnected); return }

        let ready: Bool = await withCheckedContinuation { c in
            notifyContinuation = c
            p.discoverServices([NUS.service])
            timeout(10) { [weak self] in
                guard let self, let c = self.notifyContinuation else { return }
                self.notifyContinuation = nil
                self.addLog("Service discovery timeout")
                c.resume(returning: false)
            }
        }
        guard ready else { state = .failed(.serviceMissing); return }
        addLog("Connected, data channel open")

        let hs = await handshake(peripheralID: p.identifier)
        switch hs {
        case .timeout:
            state = .failed(.noButtonPress); return
        case .failed:
            addLog("Encrypted pairing failed, trying plain protocol")
            mode = .plain
            buffer = []
            let probe = await request(Addr.bms, Cmd.read, 0x32, [2], match: isFrom(Addr.bms, Cmd.readAck, 0x32), tries: 2)
            if probe == nil {
                state = .failed(rawBytes > 0 ? .encryptedUnreadable : .noAnswer)
                return
            }
        case .ok:
            break
        }
        await measure()
    }

    private enum HandshakeResult { case ok, failed, timeout }

    private func handshake(peripheralID: UUID) async -> HandshakeResult {
        mode = .encrypted
        buffer = []
        crypto = NbCrypto(name: Array(advertisedName.utf8))
        state = .keyExchange
        addLog("Encrypted protocol, device name „\(advertisedName)“")

        guard let initFrame = await request(Addr.ble, Cmd.initial, 0, [], match: isFrom(Addr.ble, Cmd.initial, nil), tries: 3),
              initFrame.data.count >= 16 else {
            addLog("No valid INIT answer"); return .failed
        }
        let bleKey = Array(initFrame.data[0..<16])
        let serial = Array(initFrame.data[16...])
        addLog("Scooter serial: \(String(decoding: serial, as: UTF8.self))")
        crypto?.setBleData(bleKey)

        var appKey = PairingStore.load(peripheralID)
        let known = appKey != nil
        if appKey == nil {
            var k = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, &k)
            appKey = k
        }
        guard let key = appKey else { return .failed }

        guard let ping = await request(Addr.ble, Cmd.ping, 0, key, match: isFrom(Addr.ble, Cmd.ping, nil), tries: 3) else {
            addLog("No PING answer"); return .failed
        }

        if ping.arg == 1 {
            crypto?.setAppData(key)
        } else {
            if known { addLog("Stored pairing no longer accepted, pairing again") }
            var ok = false
            var s = 60
            while s > 0 && !ok {
                state = .waitingForButton(secondsLeft: s)
                let match: (Frame) -> Bool = { f in
                    f.src == Addr.ble && (f.cmd == Cmd.ping || f.cmd == Cmd.pair) && f.arg == 1
                }
                let w = register(match)
                send(Addr.ble, Cmd.pair, 0, serial)
                if let r = await wait(w, timeout: 1.0) {
                    if r.cmd == Cmd.ping { crypto?.setAppData(key) }
                    ok = true
                }
                s -= 1
            }
            if !ok { addLog("No button press within 60 s"); return .timeout }
            state = .keyExchange
        }

        var pair = await request(Addr.ble, Cmd.pair, 0, serial, match: isFrom(Addr.ble, Cmd.pair, nil), tries: 3)
        if pair == nil && crypto?.appData != nil {
            addLog("PAIR unanswered, retrying without app key")
            crypto?.setBleData(bleKey)
            pair = await request(Addr.ble, Cmd.pair, 0, serial, match: isFrom(Addr.ble, Cmd.pair, nil), tries: 3)
        }
        guard pair != nil else { addLog("No PAIR answer"); return .failed }
        PairingStore.save(key, for: peripheralID)
        addLog("Paired and authenticated")
        return .ok
    }

    private func measure() async {
        state = .reading
        var r = BatteryReading()
        r.deviceName = advertisedName

        func word(_ d: [UInt8], _ i: Int = 0) -> Int { Int(d[i]) | (Int(d[i + 1]) << 8) }
        func sword(_ d: [UInt8]) -> Int { let v = word(d); return v > 32767 ? v - 65536 : v }

        if let x = await readWords(Addr.bms, 0x32, 1) { r.percent = word(x) }
        if let x = await readWords(Addr.bms, 0x34, 1) { r.voltage = Double(word(x)) / 100 }
        if let x = await readWords(Addr.bms, 0x33, 1) { r.current = Double(sword(x)) / 100 }
        if let x = await readWords(Addr.bms, 0x35, 1) { r.temps = [Int(x[0]) - 20, Int(x[1]) - 20] }
        if let x = await readWords(Addr.bms, 0x40, 10) {
            var cells: [Int] = []
            var i = 0
            while i + 1 < x.count {
                let mv = word(x, i)
                if mv > 1000 && mv < 5000 { cells.append(mv) }
                i += 2
            }
            r.cells = cells
        }
        if let x = await readWords(Addr.bms, 0x3B, 1) { r.health = word(x) }
        if let x = await readWords(Addr.bms, 0x18, 1) { r.capacityFactory = word(x) }
        if let x = await readWords(Addr.bms, 0x19, 1) { r.capacityActual = word(x) }
        if let x = await readWords(Addr.bms, 0x31, 1) { r.capacityRemaining = word(x) }
        if let x = await readWords(Addr.bms, 0x1B, 1) { r.cycles = word(x) }
        if let x = await readWords(Addr.bms, 0x1C, 1) { r.charges = word(x) }
        if let x = await readWords(Addr.bms, 0x20, 1) {
            let v = word(x)
            r.manufactured = String(format: "%02d.%02d.%04d", v & 31, (v >> 5) & 15, 2000 + (v >> 9))
        }
        if let x = await readWords(Addr.bms, 0x17, 1) {
            let v = word(x)
            r.bmsFirmware = "\((v >> 8) & 15).\((v >> 4) & 15).\(v & 15)"
        }
        if let x = await readWords(Addr.bms, 0x10, 7) {
            r.serial = String(decoding: x.filter { $0 >= 0x20 && $0 <= 0x7E }, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        if let x = await readWords(Addr.esc, 0x29, 2), x.count >= 4 {
            let v = Int(x[0]) | (Int(x[1]) << 8) | (Int(x[2]) << 16) | (Int(x[3]) << 24)
            r.odometerKm = Double(v) / 1000
        }
        r.date = Date()
        reading = r

        if r.percent == nil && r.cells.isEmpty { state = .failed(.noBatteryData) }
        else if r.cells.count < 2 { state = .failed(.noCells) }
        else { state = .done }
        addLog("Measurement finished")
    }

    // MARK: Transport

    private func isFrom(_ src: UInt8, _ cmd: UInt8, _ arg: UInt8?) -> (Frame) -> Bool {
        { f in f.src == src && f.cmd == cmd && (arg == nil || f.arg == arg!) }
    }

    private func send(_ dst: UInt8, _ cmd: UInt8, _ arg: UInt8, _ payload: [UInt8]) {
        guard let p = peripheral, let rx = rxChar else { return }
        let bytes: [UInt8]
        switch mode {
        case .plain:
            bytes = plainFrame(dst: dst, cmd: cmd, arg: arg, payload: payload)
        case .encrypted:
            guard let c = crypto else { return }
            bytes = c.encrypt([0x5A, 0xA5, UInt8(payload.count), Addr.appEncrypted, dst, cmd, arg] + payload)
        }
        addLog("→ " + Hex.string(bytes))
        let type: CBCharacteristicWriteType = rx.properties.contains(.write) ? .withResponse : .withoutResponse
        var i = 0
        while i < bytes.count {
            let chunk = Array(bytes[i..<min(i + 20, bytes.count)])
            p.writeValue(Data(chunk), for: rx, type: type)
            i += 20
        }
    }

    /// Registers a waiter synchronously (before the request is sent), so no answer can be missed.
    private func register(_ match: @escaping (Frame) -> Bool) -> Waiter {
        let w = Waiter(match: match)
        waiters.append(w)
        return w
    }

    private func wait(_ w: Waiter, timeout: Double) async -> Frame? {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            self?.waiters.removeAll { $0 === w }
            w.finish(nil)
        }
        if w.finished { waiters.removeAll { $0 === w }; return w.result }
        return await withCheckedContinuation { (c: CheckedContinuation<Frame?, Never>) in
            if w.finished { c.resume(returning: w.result) } else { w.cont = c }
        }
    }

    private func request(_ dst: UInt8, _ cmd: UInt8, _ arg: UInt8, _ payload: [UInt8],
                         match: @escaping (Frame) -> Bool, tries: Int) async -> Frame? {
        for _ in 0..<tries {
            let w = register(match)
            send(dst, cmd, arg, payload)
            if let r = await wait(w, timeout: 1.2) { return r }
        }
        return nil
    }

    private func readWords(_ dst: UInt8, _ reg: UInt8, _ words: Int) async -> [UInt8]? {
        if mode == .plain {
            let r = await request(dst, Cmd.read, reg, [UInt8(words * 2)], match: isFrom(dst, Cmd.readAck, reg), tries: 2)
            guard let d = r?.data, d.count >= 2 else { return nil }
            return d
        }
        var out: [UInt8] = []
        for i in 0..<words {
            let a = reg &+ UInt8(i)
            guard let r = await request(dst, Cmd.read, a, [2], match: isFrom(dst, Cmd.readAck, a), tries: 3),
                  r.data.count >= 2 else {
                addLog(String(format: "   register 0x%02x: no answer", a))
                return out.count >= 2 ? out : nil
            }
            out += r.data.prefix(2)
        }
        return out
    }

    private func deliver(_ f: Frame) {
        addLog(String(format: "   = %02x→%02x cmd %02x idx %02x data ", f.src, f.dst, f.cmd, f.arg) + Hex.string(f.data))
        if let idx = waiters.firstIndex(where: { !$0.finished && $0.match(f) }) {
            let w = waiters.remove(at: idx)
            w.finish(f)
        }
    }

    private func handleNotification(_ v: [UInt8]) {
        rawBytes += v.count
        addLog("← " + Hex.string(v))
        switch mode {
        case .encrypted:
            if v.count >= 2 && v[0] == 0x5A && v[1] == 0xA5 { buffer = v } else { buffer += v }
            guard buffer.count >= 3 else { return }
            let total = Int(buffer[2]) + 13
            guard buffer.count >= total, let c = crypto else { return }
            let frame = Array(buffer[0..<total])
            buffer = []
            let d = c.decrypt(frame)
            guard d.count >= 7 else { return }
            addLog("   decrypted: " + Hex.string(d))
            deliver(Frame(src: d[3], dst: d[4], cmd: d[5], arg: d[6], data: Array(d[7...])))
        case .plain:
            buffer += v
            while true {
                guard let i = buffer.indices.first(where: { $0 + 1 < buffer.count && buffer[$0] == 0x5A && buffer[$0 + 1] == 0xA5 }) else {
                    buffer = Array(buffer.suffix(1)); return
                }
                if i > 0 { buffer = Array(buffer[i...]) }
                guard buffer.count >= 3 else { return }
                let total = Int(buffer[2]) + 9
                guard buffer.count >= total else { return }
                let f = Array(buffer[0..<total])
                buffer = Array(buffer[total...])
                let body = f[2..<(total - 2)]
                let ck = (body.reduce(0) { $0 + Int($1) } ^ 0xFFFF) & 0xFFFF
                guard ck == (Int(f[total - 2]) | (Int(f[total - 1]) << 8)) else { addLog("   checksum mismatch"); continue }
                deliver(Frame(src: f[3], dst: f[4], cmd: f[5], arg: f[6], data: Array(f[7..<(total - 2)])))
            }
        }
    }
}

// MARK: - CoreBluetooth delegates

extension ScooterSession: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated { self.updateBluetoothState() }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            let name = advName ?? peripheral.name ?? ""
            guard !name.isEmpty, self.looksLikeScooter(name: name, services: services) else { return }
            if let i = self.scooters.firstIndex(where: { $0.id == peripheral.identifier }) {
                self.scooters[i].rssi = rssi
            } else {
                self.scooters.append(DiscoveredScooter(id: peripheral.identifier, name: name, rssi: rssi, peripheral: peripheral))
                self.addLog("Found \(name) (\(rssi) dBm)")
            }
            self.scooters.sort { $0.rssi > $1.rssi }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            self.connectContinuation?.resume(returning: true)
            self.connectContinuation = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.addLog("Connect failed: \(error?.localizedDescription ?? "-")")
            self.connectContinuation?.resume(returning: false)
            self.connectContinuation = nil
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            self.addLog("Disconnected")
            self.connectContinuation?.resume(returning: false); self.connectContinuation = nil
            self.notifyContinuation?.resume(returning: false); self.notifyContinuation = nil
            for w in self.waiters { w.finish(nil) }
            self.waiters.removeAll()
            self.rxChar = nil
            self.connectedName = nil
            switch self.state {
            case .done, .failed, .idle: break
            default: self.state = .failed(.disconnected)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard let s = peripheral.services?.first(where: { $0.uuid == NUS.service }) else {
                self.notifyContinuation?.resume(returning: false); self.notifyContinuation = nil; return
            }
            peripheral.discoverCharacteristics([NUS.rx, NUS.tx], for: s)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard let chars = service.characteristics,
                  let rx = chars.first(where: { $0.uuid == NUS.rx }),
                  let tx = chars.first(where: { $0.uuid == NUS.tx }) else {
                self.notifyContinuation?.resume(returning: false); self.notifyContinuation = nil; return
            }
            self.rxChar = rx
            peripheral.setNotifyValue(true, for: tx)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let ok = error == nil && characteristic.isNotifying
        MainActor.assumeIsolated {
            self.notifyContinuation?.resume(returning: ok)
            self.notifyContinuation = nil
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == NUS.tx, let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        MainActor.assumeIsolated { self.handleNotification(bytes) }
    }
}
