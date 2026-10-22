import SwiftUI

/// Spacing scale. Screens use `screenMargin` for horizontal insets.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let screenMargin: CGFloat = 20
}

enum Radius {
    static let control: CGFloat = 12
    static let plate: CGFloat = 20
}

/// Minimum tappable size; larger than the 44pt HIG minimum for this audience.
enum TouchTarget {
    static let minimum: CGFloat = 48
    static let primaryControl: CGFloat = 72
}

enum Motion {
    /// The one animation used for state changes across the app.
    static let standard = Animation.smooth(duration: 0.35)

    static func standard(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : standard
    }
}

/// Semantic colours (the gogo palette). Values live in the asset catalog.
/// The app is always dark, so each colour has a single value.
extension ShapeStyle where Self == Color {
    static var vyumBackground: Color { .brandBackground }
    static var vyumSurface: Color { .brandSurface }
    static var vyumSurfaceEmphasis: Color { .brandSurfaceEmphasis }
    static var vyumSeparator: Color { .brandSeparator }
    static var vyumTextPrimary: Color { .brandTextPrimary }
    static var vyumTextSecondary: Color { .brandTextSecondary }
    /// Lime. Fill for primary actions and progress only.
    static var vyumAccentFill: Color { .brandAccentFill }
    /// Soft fill for selected states, always paired with a non-colour indicator.
    static var vyumAccentSoft: Color { .brandAccentSoft }
    /// Text and icons placed on `vyumAccentFill`.
    static var vyumOnAccent: Color { .brandOnAccent }
    static var vyumDisabled: Color { .brandDisabled }
    /// Fixed light backing for illustrations, which are drawn for a light surface.
    static var vyumIllustrationPlate: Color { .brandIllustrationPlate }
    /// Lavender halo behind the mascot.
    static var vyumGlow: Color { .brandGlow }
}

extension View {
    /// Standard screen background.
    func vyumScreenBackground() -> some View {
        background(Color.vyumBackground.ignoresSafeArea())
    }
}
