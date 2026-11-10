import SwiftUI

struct ReportView: View {
    let reading: BatteryReading
    @EnvironmentObject var history: HistoryStore
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            if reading.isSample {
                Label(L.t("report.sample"), systemImage: "eye")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.warn)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.warn.opacity(0.12), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            DriftHero(reading: reading, appeared: appeared)
            KPIGrid(reading: reading)
            CellsCard(reading: reading, appeared: appeared)
            HealthCard(reading: reading, appeared: appeared)
            RecordCard(reading: reading)
            VerdictCard(verdict: Verdict(reading))
            actions
            Text(L.t("footer.readonly"))
                .font(.caption)
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.1)) { appeared = true } }
        .onChange(of: reading.id) { _, _ in
            appeared = false
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.1)) { appeared = true }
        }
    }

    @ViewBuilder private var actions: some View {
        if !reading.isSample {
            HStack(spacing: 10) {
                let saved = history.contains(reading)
                SecondaryButton(title: saved ? L.t("action.saved") : L.t("action.save"),
                                systemImage: saved ? "checkmark" : "tray.and.arrow.down") {
                    history.add(reading)
                }
                .disabled(saved)
                ShareLink(item: Verdict.shareText(reading)) {
                    HStack(spacing: 8) { Image(systemName: "square.and.arrow.up"); Text(L.t("action.share")) }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Drift hero

struct DriftHero: View {
    let reading: BatteryReading
    let appeared: Bool

    var body: some View {
        let drift = reading.drift
        let level = drift.map { DriftLevel(drift: $0) }
        let color = level.map { Theme.color(for: $0) } ?? Theme.muted
        GlassCard(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: L.t("report.drift"))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(drift.map { "\($0)" } ?? "–")
                        .font(.system(size: 96, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("mV").font(.title3.weight(.medium)).foregroundStyle(Theme.muted)
                }
                if let level {
                    Text(levelText(level))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(color.opacity(0.14), in: Capsule())
                }
                DriftScale(value: appeared ? Double(min(drift ?? 0, 100)) : 0)
                Text(L.t("report.drift.caption")).font(.caption).foregroundStyle(Theme.faint)
            }
        }
        .background(
            Circle().fill(color.opacity(0.18)).blur(radius: 60).frame(width: 240, height: 240)
                .offset(x: 120, y: -80), alignment: .topTrailing)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func levelText(_ l: DriftLevel) -> String {
        switch l { case .good: return L.t("level.good"); case .watch: return L.t("level.watch"); case .critical: return L.t("level.critical") }
    }
}

struct DriftScale: View {
    let value: Double // 0…100 mV

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Theme.good.frame(width: geo.size.width * 0.30)
                        Theme.warn.frame(width: geo.size.width * 0.50)
                        Theme.bad
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .opacity(0.85)
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                        .offset(x: max(0, min(geo.size.width - 18, geo.size.width * value / 100 - 9)))
                }
            }
            .frame(height: 18)
            HStack {
                Text("0"); Spacer(); Text("30"); Spacer(); Text("80"); Spacer(); Text("100+")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.faint)
        }
    }
}

// MARK: - KPIs

struct KPIGrid: View {
    let reading: BatteryReading

    var body: some View {
        let cols = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]
        LazyVGrid(columns: cols, spacing: 1) {
            kpi(L.t("kpi.charge"), reading.percent.map { "\($0)" } ?? "–", "%")
            kpi(L.t("kpi.voltage"), Verdict.num(reading.voltage, 2), "V")
            kpi(L.t("kpi.current"), Verdict.num(reading.current, 2), "A")
            kpi(L.t("kpi.temp"), reading.temps.map { temps in temps.map { String($0) }.joined(separator: " / ") } ?? "–", "°C")
        }
        .background(Theme.line)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func kpi(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).monospacedDigit()
                Text(unit).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.bg2)
    }
}

// MARK: - Cells

struct CellsCard: View {
    let reading: BatteryReading
    let appeared: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(text: L.t("cells.title"))
                Text(L.f("cells.count", reading.cells.count, reading.cells.count))
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(reading.cells.enumerated()), id: \.offset) { i, mv in
                            CellTube(index: i, mv: mv, reading: reading, appeared: appeared)
                        }
                    }
                }
            }
        }
    }
}

struct CellTube: View {
    let index: Int
    let mv: Int
    let reading: BatteryReading
    let appeared: Bool

    var body: some View {
        let isMax = mv == reading.maxCell && reading.drift ?? 0 > 0
        let isMin = mv == reading.minCell && reading.drift ?? 0 > 0
        let fill = max(0.02, min(1, (Double(mv) - 3000) / 1200))
        let delta = Int((Double(mv) - (reading.meanCell ?? Double(mv))).rounded())
        let color: Color = isMax ? Theme.berry : isMin ? Color(red: 0.51, green: 0.71, blue: 1) : Theme.blue
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                    .frame(height: appeared ? 150 * fill : 4)
                    .padding(1)
                    .animation(.spring(response: 0.9, dampingFraction: 0.65).delay(Double(index) * 0.04), value: appeared)
            }
            .frame(width: 44, height: 152)
            Text(Verdict.num(Double(mv) / 1000, 3)).font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text("\(delta > 0 ? "+" : "")\(delta)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isMax ? Theme.berry : isMin ? Theme.blue : Theme.muted)
            Text(L.isGerman ? "Z\(index + 1)" : "C\(index + 1)").font(.caption2).foregroundStyle(Theme.faint)
        }
    }
}

// MARK: - Health & record

struct HealthCard: View {
    let reading: BatteryReading
    let appeared: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: L.t("health.title"))
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: appeared ? Double(reading.healthPercent ?? 0) / 100 : 0)
                            .stroke(AngularGradient(colors: [Theme.berry, Theme.blue, Theme.berry], center: .center),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reading.healthPercent.map { "\($0) %" } ?? "–")
                            .font(.system(size: 40, weight: .light, design: .rounded)).monospacedDigit()
                        Text(L.t("health.bms")).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                VStack(spacing: 0) {
                    InfoRow(label: L.t("health.capF"), value: reading.capacityFactory.map { "\($0) mAh" })
                    InfoRow(label: L.t("health.capA"), value: reading.capacityActual.map { "\($0) mAh" })
                    InfoRow(label: L.t("health.capR"), value: reading.capacityRemaining.map { "\($0) mAh" })
                }
            }
        }
    }
}

struct RecordCard: View {
    let reading: BatteryReading

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: L.t("file.title"))
                VStack(spacing: 0) {
                    InfoRow(label: L.t("file.cycles"), value: reading.cycles.map { String($0) })
                    InfoRow(label: L.t("file.charges"), value: reading.charges.map { String($0) })
                    InfoRow(label: L.t("file.mfg"), value: reading.manufactured)
                    InfoRow(label: L.t("file.odo"), value: reading.odometerKm.map { Verdict.num($0, 1) + " km" })
                    InfoRow(label: L.t("file.fw"), value: reading.bmsFirmware)
                    InfoRow(label: L.t("file.sn"), value: reading.serial)
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value ?? "–").monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

// MARK: - Verdict

struct VerdictCard: View {
    let verdict: Verdict

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(text: L.t("verdict.title"))
                step("A", L.t("verdict.a"), Theme.blue) { Text(verdict.situation) }
                step("B", L.t("verdict.b"), Color(red: 0.72, green: 0.55, blue: 1)) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(verdict.assessment, id: \.self) { line in
                            HStack(alignment: .top, spacing: 6) { Text("•"); Text(line) }
                        }
                    }
                }
                step("F", L.t("verdict.f"), Theme.berry) { Text(verdict.conclusion) }
            }
        }
    }

    private func step<C: View>(_ letter: String, _ title: String, _ color: Color, @ViewBuilder _ content: () -> C) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(letter)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                content().font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
