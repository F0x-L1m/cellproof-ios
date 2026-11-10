import Foundation

struct BatteryReading: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var deviceName: String = ""
    var serial: String?
    var percent: Int?
    var voltage: Double?
    var current: Double?
    var temps: [Int]?
    var cells: [Int] = []          // mV
    var health: Int?               // % as reported by BMS
    var capacityFactory: Int?      // mAh
    var capacityActual: Int?       // mAh
    var capacityRemaining: Int?    // mAh
    var cycles: Int?
    var charges: Int?
    var manufactured: String?
    var bmsFirmware: String?
    var odometerKm: Double?
    var isSample = false

    var maxCell: Int? { cells.max() }
    var minCell: Int? { cells.min() }
    var meanCell: Double? { cells.isEmpty ? nil : Double(cells.reduce(0, +)) / Double(cells.count) }
    var drift: Int? {
        guard cells.count >= 2, let mx = maxCell, let mn = minCell else { return nil }
        return mx - mn
    }

    var healthPercent: Int? {
        if let h = health, h > 0, h <= 100 { return h }
        if let f = capacityFactory, let a = capacityActual, f > 0 { return Int((Double(a) / Double(f) * 100).rounded()) }
        return nil
    }

    var maxTemp: Int? { temps?.max() }

    static let sample = BatteryReading(
        deviceName: "Ninebot Max G30D",
        serial: "SAMPLE",
        percent: 96, voltage: 41.43, current: 0, temps: [17, 16],
        cells: [4144, 4146, 4141, 4150, 4143, 4132, 4145, 4147, 4142, 4148],
        health: 95, capacityFactory: 15300, capacityActual: 14610, capacityRemaining: 14020,
        cycles: 18, charges: 41, manufactured: "14.03.2022", bmsFirmware: "1.3.2",
        odometerKm: 652.4, isSample: true)
}

enum DriftLevel: String {
    case good, watch, critical

    init(drift: Int) {
        if drift < 30 { self = .good } else if drift < 80 { self = .watch } else { self = .critical }
    }
}
