import SwiftUI

struct StatusBadge: View {
    let status: DependencyStatus
    let name: String
    
    @State private var shakeTimes: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 2)
            
            Text(titleText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            
            if case .installed(_, let version) = status {
                Text(version)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(MacYTColors.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .modifier(ShakeEffect(animatableData: shakeTimes))
        .onChange(of: status) { newStatus in
            if !newStatus.isInstalled {
                withAnimation(.default) {
                    shakeTimes += 1
                }
            }
        }
    }
    
    private var color: Color {
        switch status {
        case .installed: return MacYTColors.success
        case .broken: return .orange
        case .missing: return MacYTColors.destructive
        case .checking: return MacYTColors.textSecondary
        }
    }
    
    private var titleText: String {
        switch status {
        case .installed: return "\(name) Installed"
        case .broken: return "\(name) Broken"
        case .missing: return "\(name) Missing"
        case .checking: return "Checking \(name)..."
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
