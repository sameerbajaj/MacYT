import SwiftUI

struct StatusBadge: View {
    let status: DependencyStatus
    let name: String
    
    @State private var shakeTimes: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .shadow(color: color.opacity(0.55), radius: 4)
            
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MacYTColors.textTertiary)

                    HStack(spacing: 6) {
                        Text(titleText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(color)

                        if case .installed(_, let version) = status {
                            Text(version)
                                .lineLimit(1)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(MacYTColors.textSecondary)
                        }
                    }
            }
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: 1)
        )
        .modifier(ShakeEffect(animatableData: shakeTimes))
        .onChange(of: status) {
            if !status.isInstalled {
                withAnimation(.default) {
                    shakeTimes += 1
                }
            }
        }
    }
    
    private var color: Color {
        switch status {
        case .installed: return MacYTColors.success
            case .broken: return MacYTColors.warning
        case .missing: return MacYTColors.destructive
        case .checking: return MacYTColors.textSecondary
        }
    }
    
    private var titleText: String {
        switch status {
            case .installed: return "Ready"
            case .broken: return "Broken"
            case .missing: return "Missing"
            case .checking: return "Scanning"
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 5 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
