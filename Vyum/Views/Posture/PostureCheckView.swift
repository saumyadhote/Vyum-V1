import SwiftUI
import UIKit

/// Posture check: front, side and back photos with framing guides.
struct PostureCheckView: View {
    @State private var viewModel = PostureCaptureViewModel(camera: CameraService())
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                if viewModel.phase == .complete {
                    CompletionSummary(viewModel: viewModel)
                } else {
                    StepIndicator(current: viewModel.angle, completed: Set(viewModel.photos.keys))
                    captureArea
                    if showsTips {
                        tips
                    }
                    controls
                }
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.md)
            .vyumScreenBackground()
            .navigationTitle("Posture check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.switchCamera() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                    }
                    .disabled(viewModel.phase != .live)
                    .accessibilityLabel(viewModel.isUsingFrontCamera ? "Switch to back camera" : "Switch to front camera")
                }
            }
        }
        .task { await viewModel.prepare() }
        .onDisappear { viewModel.stop() }
        .sensoryFeedback(.success, trigger: viewModel.photos.count)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(viewModel.phase == .complete ? "All three photos taken" : "Stand in the frame")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.vyumTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if viewModel.phase != .complete {
                Text(viewModel.angle.instruction)
                    .font(.subheadline)
                    .foregroundStyle(Color.vyumTextSecondary)
            }
        }
        .padding(.top, Spacing.xs)
    }

    private var captureArea: some View {
        ZStack {
            Color.vyumSurface
            captureContent
            if showsGuides {
                CaptureFrameOverlay(angle: viewModel.angle)
            }
            if case .countdown(let remaining) = viewModel.phase {
                Text("\(remaining)")
                    .font(.system(size: 96, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.vyumTextPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 12)
                    .accessibilityLabel("Taking photo in \(remaining)")
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(.rect(cornerRadius: Radius.plate, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.plate, style: .continuous)
                .strokeBorder(Color.vyumSeparator, lineWidth: 1)
        )
    }

    @ViewBuilder private var captureContent: some View {
        switch viewModel.phase {
        case .review:
            if let data = viewModel.currentPhoto {
                CapturedPhoto(data: data)
                    .accessibilityLabel("\(viewModel.angle.title) photo")
            }
        case .live, .countdown, .capturing:
            if let session = viewModel.camera.previewSession {
                CameraPreview(session: session)
                    .accessibilityLabel("Camera preview")
            }
        case .idle, .requestingAccess:
            ProgressView()
        case .denied:
            CameraMessage(
                systemImage: "camera.badge.ellipsis",
                title: "Camera access is off",
                message: "Allow camera access in Settings to take your posture photos."
            ) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.vyumPrimary)
            }
        case .unavailable:
            CameraMessage(
                systemImage: "camera",
                title: "No camera available",
                message: "Posture check needs a camera. Try it on your iPhone."
            )
        case .failed(let message):
            CameraMessage(systemImage: "exclamationmark.triangle", title: "Something went wrong", message: message) {
                Button("Try again") {
                    Task { await viewModel.retryAfterFailure() }
                }
                .buttonStyle(.vyumSecondary)
            }
        case .complete:
            EmptyView()
        }
    }

    private var tips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.md) { tipLabels }
            VStack(alignment: .leading, spacing: Spacing.xxs) { tipLabels }
        }
    }

    @ViewBuilder private var tipLabels: some View {
        MetaLabel(text: "Use even lighting", systemImage: "lightbulb")
        MetaLabel(text: "Keep the phone steady", systemImage: "iphone")
    }

    @ViewBuilder private var controls: some View {
        switch viewModel.phase {
        case .live:
            HStack {
                timerToggle
                Spacer()
                ShutterButton(usesTimer: viewModel.usesTimer, seconds: viewModel.countdownSeconds) {
                    viewModel.capture()
                }
                Spacer()
                // Balances the timer toggle so the shutter stays centred.
                Color.clear.frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
            }
        case .countdown:
            Button("Cancel") { viewModel.cancelCountdown() }
                .buttonStyle(.vyumSecondary)
        case .capturing:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: TouchTarget.primaryControl)
        case .review:
            HStack(spacing: Spacing.sm) {
                Button("Retake") { viewModel.retake() }
                    .buttonStyle(.vyumSecondary)
                    .accessibilityIdentifier("posture.retake")
                Button(viewModel.angle == .back ? "Finish" : "Continue") { viewModel.continueToNext() }
                    .buttonStyle(.vyumPrimary)
                    .accessibilityIdentifier("posture.continue")
            }
        default:
            EmptyView()
        }
    }

    private var timerToggle: some View {
        Button {
            viewModel.usesTimer.toggle()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: viewModel.usesTimer ? "timer" : "timer.slash")
                    .font(.title3)
                Text(viewModel.usesTimer ? "\(viewModel.countdownSeconds)s" : "Off")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.vyumTextPrimary)
            .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Timer")
        .accessibilityValue(viewModel.usesTimer ? "\(viewModel.countdownSeconds) seconds" : "Off")
    }

    private var showsGuides: Bool {
        switch viewModel.phase {
        case .live, .countdown: true
        default: false
        }
    }

    private var showsTips: Bool {
        switch viewModel.phase {
        case .live, .countdown, .capturing: true
        default: false
        }
    }
}

// MARK: - Components

/// Front · Side · Back, with the current step highlighted.
private struct StepIndicator: View {
    let current: PostureAngle
    let completed: Set<PostureAngle>

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(PostureAngle.allCases) { angle in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Capsule()
                        .fill(angle == current || completed.contains(angle) ? Color.vyumAccentFill : Color.vyumSurfaceEmphasis)
                        .frame(height: 4)
                    HStack(spacing: 4) {
                        if completed.contains(angle) && angle != current {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                        }
                        Text(angle.title)
                            .font(.footnote.weight(angle == current ? .semibold : .regular))
                    }
                    .foregroundStyle(angle == current ? Color.vyumTextPrimary : Color.vyumTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of \(PostureAngle.allCases.count): \(current.title)")
    }
}

private struct ShutterButton: View {
    let usesTimer: Bool
    let seconds: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.vyumAccentFill)
                .padding(6)
                .overlay(Circle().strokeBorder(Color.vyumTextPrimary, lineWidth: 3))
                .frame(width: TouchTarget.primaryControl, height: TouchTarget.primaryControl)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take photo")
        .accessibilityHint(usesTimer ? "Starts a \(seconds)-second timer" : "Takes the photo now")
        .accessibilityIdentifier("posture.shutter")
    }
}

private struct CameraMessage<Actions: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    init(systemImage: String, title: String, message: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color.vyumTextSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.vyumTextPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.vyumTextSecondary)
                .multilineTextAlignment(.center)
            actions
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
    }
}

private struct CompletionSummary: View {
    let viewModel: PostureCaptureViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                ForEach(PostureAngle.allCases) { angle in
                    VStack(spacing: Spacing.xxs) {
                        Group {
                            if let data = viewModel.photos[angle] {
                                CapturedPhoto(data: data)
                            } else {
                                Color.vyumSurface
                            }
                        }
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: Radius.control, style: .continuous))
                        Text(angle.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.vyumTextSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(angle.title) photo")
                }
            }

            NoteBox(
                title: "Posture analysis is coming",
                message: "For now, gogo takes the photos but doesn't analyse them. They're kept only until you leave the app and are never uploaded.",
                systemImage: "info.circle"
            )

            Spacer(minLength: 0)

            Button("Start over") {
                Task { await viewModel.startOver() }
            }
            .buttonStyle(.vyumPrimary)
        }
    }
}

#Preview {
    PostureCheckView()
}
