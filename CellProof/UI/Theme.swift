import SwiftUI

enum Theme {
    static let bg = Color(red: 0.027, green: 0.024, blue: 0.047)
    static let bg2 = Color(red: 0.051, green: 0.043, blue: 0.086)
    static let berry = Color(red: 0.878, green: 0.271, blue: 0.482)
    static let blue = Color(red: 0.298, green: 0.553, blue: 1.0)
    static let good = Color(red: 0.247, green: 0.839, blue: 0.604)
    static let warn = Color(red: 0.965, green: 0.741, blue: 0.235)
    static let bad = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let muted = Color.white.opacity(0.58)
    static let faint = Color.white.opacity(0.36)
    static let line = Color.white.opacity(0.09)

    static let accent = LinearGradient(colors: [berry, Color(red: 0.69, green: 0.23, blue: 0.88), blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)

    static func color(for level: DriftLevel) -> Color {
        switch level { case .good: return good; case .watch: return warn; case .critical: return bad }
    }
}

struct ObservatoryBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.berry.opacity(0.28), .clear], center: .topTrailing, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Theme.blue.opacity(0.22), .clear], center: .leading, startRadius: 10, endRadius: 480)
            RadialGradient(colors: [Theme.berry.opacity(0.12), .clear], center: .bottom, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.muted)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.berry.opacity(0.45), radius: 18, y: 8)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(SpringButtonStyle())
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
