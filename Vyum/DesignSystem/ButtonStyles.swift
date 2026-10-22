import SwiftUI

/// Full-width primary action: periwinkle fill with ink label (6.2:1 contrast).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.vyumOnAccent : Color.vyumTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Spacing.md)
            .background(
                isEnabled ? Color.vyumAccentFill : Color.vyumDisabled,
                in: .rect(cornerRadius: Radius.control, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(.rect)
    }
}

/// Secondary action: warm fill with a hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.vyumTextPrimary : Color.vyumTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Spacing.md)
            .background(
                configuration.isPressed ? Color.vyumAccentSoft : Color.vyumSurfaceEmphasis,
                in: .rect(cornerRadius: Radius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Color.vyumSeparator, lineWidth: 1)
            )
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var vyumPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var vyumSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
