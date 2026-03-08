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
                    .fontWeight(.medium)
            }
            .padding(.horizontal, MacYTSpacing.lg)
            .padding(.vertical, MacYTSpacing.sm)
            .frame(minWidth: 100)
            .background(
                LinearGradient(
                    colors: [MacYTColors.accentGradientStart, MacYTColors.accentGradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: MacYTCornerRadius.medium))
            .shadow(color: MacYTColors.accentGradientStart.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 6 : 3, y: 2)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }
}
