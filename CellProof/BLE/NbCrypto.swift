import Foundation
import CommonCrypto
import CryptoKit

/// Ninebot BLE encryption (newer firmware).
/// Own implementation of the publicly documented scheme:
/// AES-128-ECB keystream, CBC-MAC tag, SHA-1 key derivation, 16-bit packet counter.
final class NbCrypto {
    static let fwData: [UInt8] = [0x97, 0xCF, 0xB8, 0x02, 0x84, 0x41, 0x43, 0xDE,
                                  0x56, 0x00, 0x2B, 0x3B, 0x34, 0x78, 0x0A, 0x5D]

    private let name: [UInt8]
    private(set) var bleData: [UInt8]?
    private(set) var appData: [UInt8]?
    var counter: UInt32 = 0
    private var key: [UInt8]

    init(name: [UInt8]) {
        self.name = name
        self.key = NbCrypto.derive(name, NbCrypto.fwData)
    }

    func setBleData(_ data: [UInt8]) {
        bleData = data
        key = NbCrypto.derive(name, data)
    }

    func setAppData(_ data: [UInt8]) {
        appData = data
        key = NbCrypto.derive(data, bleData ?? [])
    }

    // MARK: Primitives

    /// First 16 bytes of SHA-1 over (a padded/truncated to 16) || (b padded/truncated to 16).
    static func derive(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 32)
        for i in 0..<min(16, a.count) { buf[i] = a[i] }
        for i in 0..<min(16, b.count) { buf[16 + i] = b[i] }
        let digest = Insecure.SHA1.hash(data: Data(buf))
        return Array(Array(digest).prefix(16))
    }

    static func aes(_ block: [UInt8], _ key: [UInt8]) -> [UInt8] {
        var input = [UInt8](repeating: 0, count: 16)
        for i in 0..<min(16, block.count) { input[i] = block[i] }
        var output = [UInt8](repeating: 0, count: 32)
        var moved: Int = 0
        let status = key.withUnsafeBytes { keyPtr in
            input.withUnsafeBytes { inPtr in
                output.withUnsafeMutableBytes { outPtr in
                    CCCrypt(CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionECBMode),
                            keyPtr.baseAddress, kCCKeySizeAES128,
                            nil,
                            inPtr.baseAddress, 16,
                            outPtr.baseAddress, 32,
                            &moved)
                }
            }
        }
        precondition(status == Int32(kCCSuccess), "AES failed")
        return Array(output.prefix(16))
    }

    private func aesData() -> [UInt8] {
        var a = [UInt8](repeating: 0, count: 16)
        a[0] = 1
        a[1] = UInt8((counter >> 24) & 0xFF)
        a[2] = UInt8((counter >> 16) & 0xFF)
        a[3] = UInt8((counter >> 8) & 0xFF)
        a[4] = UInt8(counter & 0xFF)
        if let ble = bleData {
            for i in 0..<min(8, ble.count) { a[5 + i] = ble[i] }
        }
        return a
    }

    /// Static keystream (counter 0 / before key exchange).
    private func streamStatic(_ input: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: input.count)
        let ks = NbCrypto.aes(NbCrypto.fwData, key)
        var i = 0
        while i < input.count {
            var j = 0
            while j < 16 && i + j < input.count { out[i + j] = input[i + j] ^ ks[j]; j += 1 }
            i += 16
        }
        return out
    }

    /// Counter keystream; mutates `aes[15]` per block exactly like the reference.
    private func streamCounter(_ input: [UInt8], _ aesBlock: inout [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: input.count)
        var i = 0
        while i < input.count {
            aesBlock[15] = aesBlock[15] &+ 1
            let ks = NbCrypto.aes(aesBlock, key)
            var j = 0
            while j < 16 && i + j < input.count { out[i + j] = input[i + j] ^ ks[j]; j += 1 }
            i += 16
        }
        return out
    }

    private func mac(_ data: [UInt8], _ aesBlock: inout [UInt8]) -> [UInt8] {
        var x = NbCrypto.aes(aesBlock, key)
        var h = [UInt8](repeating: 0, count: 16)
        for i in 0..<3 { h[i] = data[i] }
        for i in 0..<16 { h[i] ^= x[i] }
        x = NbCrypto.aes(h, key)
        var i = 3
        while i < data.count {
            var b = [UInt8](repeating: 0, count: 16)
            var j = 0
            while j < 16 && i + j < data.count { b[j] = data[i + j]; j += 1 }
            for k in 0..<16 { b[k] ^= x[k] }
            x = NbCrypto.aes(b, key)
            i += 16
        }
        aesBlock[0] = 1
        aesBlock[15] = 0
        let e = NbCrypto.aes(aesBlock, key)
        return [e[0] ^ x[0], e[1] ^ x[1], e[2] ^ x[2], e[3] ^ x[3]]
    }

    // MARK: Public

    /// `data` = plain frame: 5A A5 len src dst cmd arg payload (no checksum).
    func encrypt(_ data: [UInt8]) -> [UInt8] {
        let pl = Array(data[3...])
        var out = [UInt8](repeating: 0, count: pl.count + 9)
        for i in 0..<3 { out[i] = data[i] }
        if counter == 0 || bleData == nil {
            let sum = pl.reduce(0) { $0 + Int($1) }
            let crc = (~sum) & 0xFFFF
            let enc = streamStatic(pl)
            for i in 0..<enc.count { out[3 + i] = enc[i] }
            out[pl.count + 5] = UInt8(crc & 0xFF)
            out[pl.count + 6] = UInt8((crc >> 8) & 0xFF)
        } else {
            counter &+= 1
            var a = aesData()
            let enc = streamCounter(pl, &a)
            for i in 0..<enc.count { out[3 + i] = enc[i] }
            a[0] = 0x59
            a[15] = UInt8(pl.count & 0xFF)
            let tag = mac(data, &a)
            for i in 0..<4 { out[pl.count + 3 + i] = tag[i] }
            out[pl.count + 7] = UInt8((counter >> 8) & 0xFF)
            out[pl.count + 8] = UInt8(counter & 0xFF)
        }
        return out
    }

    /// Returns plain frame without trailer: 5A A5 len src dst cmd arg payload.
    func decrypt(_ data: [UInt8]) -> [UInt8] {
        guard data.count >= 9 else { return [] }
        let pl = Array(data[3..<(data.count - 6)])
        counter = (UInt32(data[data.count - 2]) << 8) | UInt32(data[data.count - 1])
        var out = Array(data[0..<3])
        if counter == 0 || bleData == nil {
            out += streamStatic(pl)
        } else {
            var a = aesData()
            out += streamCounter(pl, &a)
        }
        return out
    }
}
