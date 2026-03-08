import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.15), location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .init(x: -1 + phase, y: 0.5),
                        endPoint: .init(x: 0 + phase, y: 0.5)
                    )
                )
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .mask(Rectangle())
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

extension View {
    func shimmerEffect() -> some View {
        self.overlay(ShimmerView().mask(self))
    }
}
