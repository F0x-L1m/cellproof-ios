import SwiftUI

@main
struct CellProofApp: App {
    @StateObject private var session = ScooterSession()
    @StateObject private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                CheckView()
                    .tabItem { Label(L.t("tab.check"), systemImage: "bolt.batteryblock") }
                HistoryView()
                    .tabItem { Label(L.t("tab.history"), systemImage: "chart.line.uptrend.xyaxis") }
            }
            .tint(Theme.berry)
            .environmentObject(session)
            .environmentObject(history)
            .preferredColorScheme(.dark)
        }
    }
}
