import SwiftUI
import UIKit

struct CheckView: View {
    @EnvironmentObject var session: ScooterSession
    @State private var showScan = false
    @State private var showLog = false
    @State private var showSample = false

    var body: some View {
        NavigationStack {
            ZStack {
                ObservatoryBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        statusArea
                        if let r = session.reading {
                            ReportView(reading: r)
                            HStack(spacing: 10) {
                                SecondaryButton(title: L.t("action.remeasure"), systemImage: "arrow.clockwise") { session.remeasure() }
                                SecondaryButton(title: L.t("action.newScan"), systemImage: "dot.radiowaves.left.and.right") {
                                    session.disconnect(); showScan = true; session.startScan()
                                }
                            }
                        } else if showSample {
                            ReportView(reading: .sample)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                if case .waitingForButton(let s) = session.state {
                    PairingOverlay(secondsLeft: s)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: session.state)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLog = true } label: { Image(systemName: "waveform.path.ecg.rectangle") }
                        .accessibilityLabel(L.t("action.log"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showScan, onDismiss: { session.stopScan() }) {
                ScanSheet(isPresented: $showScan).environmentObject(session)
            }
            .sheet(isPresented: $showLog) { LogSheet().environmentObject(session) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent)
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.bg2).padding(4)
                Image(systemName: "bolt.batteryblock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent)
            }
            .frame(width: 40, height: 40)
            .shadow(color: Theme.berry.opacity(0.5), radius: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text("CellProof").font(.system(size: 22, weight: .bold, design: .rounded))
                Text(session.connectedName ?? L.t("app.subtitle")).font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var statusArea: some View {
        switch session.state {
        case .idle, .scanning, .bluetoothOff, .unauthorized:
            if session.reading == nil { intro }
        case .connecting:
            StatusPill(text: L.t("state.connecting"), busy: true)
        case .keyExchange:
            StatusPill(text: L.t("state.keyExchange"), busy: true)
        case .waitingForButton:
            StatusPill(text: L.t("pair.title"), busy: true)
        case .reading:
            StatusPill(text: L.t("state.reading"), busy: true)
        case .done:
            EmptyView()
        case .failed(let f):
            failure(f)
        }
    }

    private var intro: some View {
        GlassCard(padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L.t("home.title"))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L.t("home.body")).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                if session.state == .bluetoothOff {
                    Label(L.t("state.bluetoothOff"), systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warn).font(.subheadline)
                }
                if session.state == .unauthorized {
                    Label(L.t("state.unauthorized"), systemImage: "lock").foregroundStyle(Theme.warn).font(.subheadline)
                }
                PrimaryButton(title: L.t("home.scan"), systemImage: "dot.radiowaves.left.and.right") {
                    showSample = false
                    showScan = true
                    session.startScan()
                }
                if !showSample {
                    Button(L.t("home.sample")) { withAnimation(.spring) { showSample = true } }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func failure(_ f: SessionState.Failure) -> some View {
        let text: String
        switch f {
        case .noButtonPress: text = L.t("fail.noButtonPress")
        case .encryptedUnreadable: text = L.t("fail.encryptedUnreadable")
        case .noAnswer: text = L.t("fail.noAnswer")
        case .noBatteryData: text = L.t("fail.noBatteryData")
        case .noCells: text = L.t("fail.noCells")
        case .disconnected: text = L.t("fail.disconnected")
        case .serviceMissing: text = L.t("fail.serviceMissing")
        }
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.bad)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    SecondaryButton(title: L.t("action.retry"), systemImage: "arrow.clockwise") { showScan = true; session.startScan() }
                    SecondaryButton(title: L.t("action.log"), systemImage: "doc.text") { showLog = true }
                }
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    var busy = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.blue).frame(width: 9, height: 9)
                .opacity(pulse ? 0.3 : 1)
                .animation(busy ? .easeInOut(duration: 0.8).repeatForever() : .default, value: pulse)
            Text(text).font(.subheadline.weight(.medium))
            Spacer()
            if busy { ProgressView().tint(.white) }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        .onAppear { pulse = true }
    }
}

struct PairingOverlay: View {
    let secondsLeft: Int
    @State private var glow = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Theme.blue.opacity(0.55), Theme.berry.opacity(0.15)], center: .center, startRadius: 4, endRadius: 80))
                        .frame(width: 150, height: 150)
                        .scaleEffect(glow ? 1.08 : 0.94)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: glow)
                    VStack(spacing: 2) {
                        Image(systemName: "power").font(.system(size: 30, weight: .semibold))
                        Text("\(secondsLeft)").font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
                Text(L.t("pair.title")).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                Text(L.t("pair.body")).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Theme.blue.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
        .onAppear {
            glow = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

struct ScanSheet: View {
    @EnvironmentObject var session: ScooterSession
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ObservatoryBackground()
                List {
                    Section {
                        if session.scooters.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text(L.t("scan.searching")).foregroundStyle(Theme.muted)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        ForEach(session.scooters) { s in
                            Button {
                                isPresented = false
                                session.connectAndMeasure(s)
                            } label: {
                                HStack {
                                    Image(systemName: "scooter").font(.title3).foregroundStyle(Theme.accent).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.body.weight(.semibold)).foregroundStyle(.white)
                                        Text(signal(s.rssi)).font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.faint)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } footer: {
                        Text(L.t("scan.hint")).foregroundStyle(Theme.faint)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L.t("scan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("scan.cancel")) { isPresented = false } }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func signal(_ rssi: Int) -> String {
        rssi > -60 ? L.t("scan.signal.strong") : rssi > -80 ? L.t("scan.signal.medium") : L.t("scan.signal.weak")
    }
}

struct LogSheet: View {
    @EnvironmentObject var session: ScooterSession
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(session.log.isEmpty ? "–" : session.logText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle(L.t("action.log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("action.done")) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button(copied ? L.t("action.copied") : L.t("action.copyLog")) {
                        UIPasteboard.general.string = session.logText
                        copied = true
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(L.t("action.forget"), role: .destructive) { session.forgetPairings() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
