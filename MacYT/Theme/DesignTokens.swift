import SwiftUI

enum MacYTColors {
    static let background = Color("Background", bundle: nil) // Or just use manual light/dark configs
    static let cardSurface = Color("CardSurface")
    static let cardSurfaceHover = Color("CardSurfaceHover")
    static let accentGradientStart = Color(red: 124/255, green: 92/255, blue: 252/255) // #7C5CFC
    static let accentGradientEnd = Color(red: 74/255, green: 144/255, blue: 226/255)  // #4A90E2
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    static let success = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let destructive = Color.red
    
    static let separator = Color(NSColor.separatorColor)
}

enum MacYTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum MacYTCornerRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 12
    static let pill: CGFloat = 100
}

struct MacYTCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large)
                    .fill(isHovered ? Color(NSColor.windowBackgroundColor).opacity(0.8) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MacYTCornerRadius.large)
                    .stroke(MacYTColors.separator, lineWidth: 0.5)
            )
            .shadow(color: colorScheme == .light ? Color.black.opacity(0.05) : Color.clear,
                    radius: 2, y: 1)
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
}
