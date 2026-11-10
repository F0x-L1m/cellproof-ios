import Foundation
import CoreBluetooth

enum NUS {
    static let service = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let rx = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write → scooter
    static let tx = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify ← scooter
}

enum Addr {
    static let esc: UInt8 = 0x20
    static let ble: UInt8 = 0x21
    static let bms: UInt8 = 0x22
    static let appEncrypted: UInt8 = 0x3D
    static let appPlain: UInt8 = 0x3E
}

enum Cmd {
    static let read: UInt8 = 0x01
    static let readAck: UInt8 = 0x04
    static let initial: UInt8 = 0x5B
    static let ping: UInt8 = 0x5C
    static let pair: UInt8 = 0x5D
}

struct Frame {
    let src: UInt8
    let dst: UInt8
    let cmd: UInt8
    let arg: UInt8
    let data: [UInt8]
}

enum WireMode { case encrypted, plain }

enum Hex {
    static func string(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

/// Plain (legacy, unencrypted) frame with 16-bit checksum.
func plainFrame(dst: UInt8, cmd: UInt8, arg: UInt8, payload: [UInt8]) -> [UInt8] {
    let body: [UInt8] = [UInt8(payload.count), Addr.appPlain, dst, cmd, arg] + payload
    let sum = body.reduce(0) { $0 + Int($1) }
    let ck = (sum ^ 0xFFFF) & 0xFFFF
    return [0x5A, 0xA5] + body + [UInt8(ck & 0xFF), UInt8((ck >> 8) & 0xFF)]
}

/// Small Keychain wrapper for the per-scooter pairing key.
enum PairingStore {
    private static let service = "de.foxlim.cellproof.pairing"

    static func load(_ id: UUID) -> [UInt8]? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: id.uuidString,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let d = item as? Data else { return nil }
        return [UInt8](d)
    }

    static func save(_ key: [UInt8], for id: UUID) {
        remove(id)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: id.uuidString,
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                kSecValueData as String: Data(key)]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func remove(_ id: UUID) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: id.uuidString]
        SecItemDelete(q as CFDictionary)
    }

    static func removeAll() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service]
        SecItemDelete(q as CFDictionary)
    }
}
