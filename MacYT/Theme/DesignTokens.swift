import SwiftUI

enum MacYTColors {
    static let background = Color(red: 11/255, green: 14/255, blue: 26/255)
    static let backgroundSecondary = Color(red: 26/255, green: 33/255, blue: 57/255)
    static let cardSurface = Color(red: 21/255, green: 27/255, blue: 47/255)
    static let cardSurfaceHover = Color(red: 34/255, green: 42/255, blue: 72/255)
    static let panelHighlight = Color.white.opacity(0.12)
    static let accentGradientStart = Color(red: 129/255, green: 99/255, blue: 255/255)
    static let accentGradientEnd = Color(red: 78/255, green: 194/255, blue: 255/255)
    static let accentGlow = Color(red: 118/255, green: 112/255, blue: 255/255)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.78)
    static let textTertiary = Color.white.opacity(0.58)

    static let success = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let warning = Color(red: 1.0, green: 176/255, blue: 73/255)
    static let destructive = Color(red: 1.0, green: 98/255, blue: 109/255)

    static let separator = Color.white.opacity(0.12)
}

enum MacYTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum MacYTCornerRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let pill: CGFloat = 100
}

struct MacYTCardModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? MacYTColors.cardSurfaceHover : MacYTColors.cardSurface,
                                MacYTColors.background.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.xLarge, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [MacYTColors.panelHighlight, MacYTColors.separator],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.34 : 0.24), radius: isHovered ? 30 : 22, y: 18)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func macYTCard() -> some View {
        modifier(MacYTCardModifier())
    }

    func macYTControlSurface() -> some View {
        self
            .padding(.horizontal, MacYTSpacing.md)
            .padding(.vertical, MacYTSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.medium, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.medium, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct MacYTBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MacYTColors.background, MacYTColors.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(MacYTColors.accentGradientStart.opacity(0.22))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: -260, y: -180)

            Circle()
                .fill(MacYTColors.accentGradientEnd.opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: 280, y: -160)

            Circle()
                .fill(MacYTColors.warning.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: 120, y: 260)

            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
                    .opacity(0.5)
            }
        }
        .ignoresSafeArea()
    }
}

struct MacYTSectionHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundColor(MacYTColors.accentGradientEnd)

            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(MacYTColors.textPrimary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(MacYTColors.textSecondary)
        }
    }
}

struct MacYTInfoChip: View {
    let icon: String
    let label: String
    var tint: Color = MacYTColors.textSecondary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundColor(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MacYTInlineBanner: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: MacYTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MacYTColors.textPrimary)
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MacYTColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}
