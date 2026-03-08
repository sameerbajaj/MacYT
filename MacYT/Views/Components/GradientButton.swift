import SwiftUI

struct GradientButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: MacYTSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, MacYTSpacing.xl)
            .padding(.vertical, MacYTSpacing.md)
            .frame(minWidth: 120)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous))
            .shadow(
                color: MacYTColors.accentGlow.opacity(isHovered ? 0.48 : 0.28),
                radius: isHovered ? 16 : 10,
                y: isHovered ? 10 : 6
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.top, 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }
}
