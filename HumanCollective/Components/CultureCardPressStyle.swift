import SwiftUI

struct CultureCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CultureCardPressStyle {
    static var cultureCard: CultureCardPressStyle {
        CultureCardPressStyle()
    }
}
