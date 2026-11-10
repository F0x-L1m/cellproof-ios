import Foundation
import SwiftUI

struct Verdict {
    let situation: String
    let assessment: [String]
    let conclusion: String

    static func num(_ v: Double?, _ digits: Int) -> String {
        guard let v else { return "–" }
        let f = NumberFormatter()
        f.minimumFractionDigits = digits
        f.maximumFractionDigits = digits
        f.locale = Locale.current
        return f.string(from: NSNumber(value: v)) ?? "–"
    }

    init(_ r: BatteryReading) {
        let cells = r.cells
        var b: [String] = []

        if let drift = r.drift, let mx = r.maxCell, let mn = r.minCell,
           let iMax = cells.firstIndex(of: mx), let iMin = cells.firstIndex(of: mn) {
            situation = L.f("v.a.cells", cells.count, r.percent ?? 0, Verdict.num(r.voltage, 2),
                            r.maxTemp.map { String($0) } ?? "–", Verdict.num(r.current, 2))
            let level = DriftLevel(drift: drift)
            let tail: String
            switch level {
            case .good: tail = L.t("v.b.drift.good")
            case .watch: tail = L.t("v.b.drift.watch")
            case .critical: tail = L.t("v.b.drift.critical")
            }
            b.append(L.f("v.b.drift", drift, iMax + 1, Verdict.num(Double(mx) / 1000, 3), iMin + 1, Verdict.num(Double(mn) / 1000, 3)) + " " + tail)
            switch level {
            case .good: conclusion = L.t("v.f.good")
            case .watch: conclusion = L.t("v.f.watch")
            case .critical: conclusion = L.f("v.f.critical", iMin + 1)
            }
        } else {
            situation = L.t("v.a.nocells")
            conclusion = L.t("v.f.nocells")
        }

        if let h = r.healthPercent {
            let tail = h >= 90 ? L.t("v.b.health.good") : h >= 80 ? L.t("v.b.health.ok") : L.t("v.b.health.bad")
            b.append(L.f("v.b.health", h) + " " + tail)
        }
        if let c = r.cycles {
            let tail = c < 100 ? L.t("v.b.cycles.low") : c < 300 ? L.t("v.b.cycles.mid") : L.t("v.b.cycles.high")
            b.append(L.f("v.b.cycles", c) + " " + tail)
        }
        if let cur = r.current, abs(cur) > 0.5 { b.append(L.t("v.b.load")) }
        if let p = r.percent, p < 80 { b.append(L.t("v.b.soc")) }
        if let t = r.maxTemp, t < 10 { b.append(L.t("v.b.cold")) }
        assessment = b
    }

    static func shareText(_ r: BatteryReading) -> String {
        let v = Verdict(r)
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var lines = ["\(L.t("share.header")) · \(r.deviceName)", df.string(from: r.date), ""]
        if let d = r.drift { lines.append("\(L.t("report.drift")): \(d) mV") }
        if let h = r.healthPercent { lines.append("\(L.t("health.title")): \(h) %") }
        if let c = r.cycles { lines.append("\(L.t("file.cycles")): \(c)") }
        if let p = r.percent { lines.append("\(L.t("kpi.charge")): \(p) %") }
        if let o = r.odometerKm { lines.append("\(L.t("file.odo")): \(num(o, 1)) km") }
        if let s = r.serial, !s.isEmpty { lines.append("\(L.t("file.sn")): \(s)") }
        lines += ["", "\(L.t("verdict.a")): \(v.situation)"]
        lines += v.assessment.map { "• \($0)" }
        lines += ["\(L.t("verdict.f")): \(v.conclusion)"]
        return lines.joined(separator: "\n")
    }
}

/// Saved measurements as a JSON file (simple, portable, widget-ready later).
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [BatteryReading] = []
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("history.json")
        if let d = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([BatteryReading].self, from: d) {
            items = list
        }
    }

    func add(_ r: BatteryReading) {
        guard !r.isSample, !items.contains(where: { $0.id == r.id }) else { return }
        items.append(r)
        items.sort { $0.date > $1.date }
        persist()
    }

    func contains(_ r: BatteryReading) -> Bool { items.contains { $0.id == r.id } }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(items) { try? d.write(to: url, options: .atomic) }
    }
}
