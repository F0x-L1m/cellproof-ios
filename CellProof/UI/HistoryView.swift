import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @State private var selected: BatteryReading?

    var body: some View {
        NavigationStack {
            ZStack {
                ObservatoryBackground()
                if history.items.isEmpty {
                    GlassCard(padding: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis").font(.title).foregroundStyle(Theme.accent)
                            Text(L.t("history.empty")).foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(16)
                } else {
                    List {
                        if history.items.count >= 2 {
                            Section {
                                trendChart.listRowBackground(Color.white.opacity(0.05))
                            }
                        }
                        Section {
                            ForEach(history.items) { r in
                                Button { selected = r } label: { row(r) }
                                    .listRowBackground(Color.white.opacity(0.05))
                            }
                            .onDelete { history.delete(at: $0) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L.t("tab.history"))
            .sheet(item: $selected) { r in
                NavigationStack {
                    ScrollView { ReportView(reading: r).padding(16) }
                        .background(ObservatoryBackground())
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.t("action.done")) { selected = nil } } }
                }
                .preferredColorScheme(.dark)
                .environmentObject(history)
            }
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: L.t("history.driftTrend"))
            Chart {
                ForEach(history.items.filter { $0.drift != nil }) { r in
                    AreaMark(x: .value("Date", r.date), y: .value("mV", r.drift ?? 0))
                        .foregroundStyle(LinearGradient(colors: [Theme.berry.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Date", r.date), y: .value("mV", r.drift ?? 0))
                        .foregroundStyle(Theme.berry)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Date", r.date), y: .value("mV", r.drift ?? 0))
                        .foregroundStyle(Theme.berry)
                }
                RuleMark(y: .value("limit", 30))
                    .foregroundStyle(Theme.good.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYAxisLabel("mV")
            .frame(height: 170)
        }
        .padding(.vertical, 8)
    }

    private func row(_ r: BatteryReading) -> some View {
        let level = r.drift.map { DriftLevel(drift: $0) }
        return HStack(spacing: 12) {
            Circle().fill(level.map { Theme.color(for: $0) } ?? Theme.muted).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.deviceName).font(.body.weight(.semibold)).foregroundStyle(.white)
                Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(r.drift.map { "\($0) mV" } ?? "–").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                Text(r.healthPercent.map { "\($0) %" } ?? "–").font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
            }
        }
    }
}
