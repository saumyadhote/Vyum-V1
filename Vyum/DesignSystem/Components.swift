import SwiftUI

/// An exercise illustration. Only the gogo artwork is shown; exercises without it
/// (or still on the old drawings) get a black "Coming soon" panel.
struct IllustrationPlate: View {
    let imageName: String?
    let description: String
    var maxHeight: CGFloat = 260

    var body: some View {
        if let imageName, Artwork.isApproved(imageName) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .background(Color.vyumSurface)
                .clipShape(.rect(cornerRadius: Radius.plate, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel(description)
                .accessibilityAddTraits(.isImage)
        } else {
            Text("Coming soon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.vyumTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: min(maxHeight, 200))
                .background(Color.black, in: .rect(cornerRadius: Radius.plate, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel("Illustration coming soon")
        }
    }
}

/// Small thumbnail for list rows: the gogo artwork, or a plain blank box.
struct IllustrationThumbnail: View {
    let imageName: String?
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 64

    var body: some View {
        Group {
            if let imageName, Artwork.isApproved(imageName) {
                // Wide multi-pose guides: show the middle poses, cropped to the square.
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .background(Color.vyumSurface)
            } else {
                Color.vyumSurfaceEmphasis
                    .frame(width: size, height: size)
            }
        }
        .clipShape(.rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// An icon-plus-text fact, e.g. duration or position. Never relies on the icon alone.
struct MetaLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .imageScale(.small)
        }
        .font(.subheadline)
        .foregroundStyle(Color.vyumTextSecondary)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thin separator in the brand line colour.
struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.vyumSeparator)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A list row for an exercise, used in Library and routine details.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Spacing.md) {
            IllustrationThumbnail(imageName: exercise.illustration)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                Text(exercise.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.sm) { meta }
                    VStack(alignment: .leading, spacing: Spacing.xxs) { meta }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DisclosureChevron()
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var meta: some View {
        MetaLabel(text: DurationText.short(exercise.duration), systemImage: "clock")
        MetaLabel(text: exercise.position.title, systemImage: exercise.position.systemImage)
    }
}

/// A list row for a routine.
struct RoutineRow: View {
    let routine: Routine
    let plan: SessionPlan

    var body: some View {
        HStack(spacing: Spacing.md) {
            IllustrationThumbnail(imageName: plan.exercises.first?.illustration)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(routine.title)
                    .font(.headline)
                    .foregroundStyle(Color.vyumTextPrimary)
                Text(routine.summary)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .lineLimit(2)
                MetaLabel(
                    text: "\(plan.roundedMinutes) min · \(plan.exercises.count) exercises",
                    systemImage: "clock"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DisclosureChevron()
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct DisclosureChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.vyumTextSecondary)
            .accessibilityHidden(true)
    }
}

/// A selectable row with a visible checkmark, so selection never depends on colour alone.
struct SelectableRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    /// Artwork shown instead of the symbol, e.g. the posture-strain figures for body areas.
    var imageName: String?
    let isSelected: Bool
    var isRadio = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .frame(width: 32)
                        .foregroundStyle(Color.vyumTextPrimary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.vyumTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.vyumTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: indicatorSymbol)
                    .font(.title2)
                    .foregroundStyle(Color.vyumTextPrimary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(minHeight: TouchTarget.minimum)
            .background(
                isSelected ? Color.vyumAccentSoft : Color.vyumSurface,
                in: .rect(cornerRadius: Radius.control, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(isSelected ? Color.vyumTextPrimary : Color.vyumSeparator, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var indicatorSymbol: String {
        if isRadio {
            isSelected ? "largecircle.fill.circle" : "circle"
        } else {
            isSelected ? "checkmark.circle.fill" : "circle"
        }
    }
}

/// A calm, non-alarming note for safety information.
struct NoteBox: View {
    let title: String
    let message: String
    var systemImage = "heart.text.square"

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.vyumTextPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(Color.vyumSurfaceEmphasis, in: .rect(cornerRadius: Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Empty, error and similar placeholder states.
struct StateMessage<Actions: View>: View {
    let title: String
    let message: String
    var imageName: String?
    var systemImage: String?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: Spacing.md) {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(Color.vyumTextSecondary)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.vyumTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.vyumTextSecondary)
                .multilineTextAlignment(.center)
            actions()
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}

extension StateMessage where Actions == EmptyView {
    init(title: String, message: String, imageName: String? = nil, systemImage: String? = nil) {
        self.init(title: title, message: message, imageName: imageName, systemImage: systemImage) { EmptyView() }
    }
}

enum DurationText {
    /// "45 sec", "1 min", "1 min 30 sec".
    static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let remainder = total % 60
        switch (minutes, remainder) {
        case (0, _): return "\(remainder) sec"
        case (_, 0): return "\(minutes) min"
        default: return "\(minutes) min \(remainder) sec"
        }
    }

    /// "0:45" style countdown.
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Spoken form for VoiceOver, e.g. "45 seconds remaining".
    static func spokenRemaining(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 60 ? [.minute, .second] : [.second]
        let value = formatter.string(from: TimeInterval(seconds)) ?? "\(seconds) seconds"
        return "\(value) remaining"
    }
}
