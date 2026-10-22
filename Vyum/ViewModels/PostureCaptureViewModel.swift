import Foundation
import Observation

/// The three photos a posture check takes, in order.
enum PostureAngle: Int, CaseIterable, Identifiable, Sendable {
    case front
    case side
    case back

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .front: "Front"
        case .side: "Side"
        case .back: "Back"
        }
    }

    var instruction: String {
        switch self {
        case .front: "Face the camera, arms relaxed by your sides."
        case .side: "Turn so your right side faces the camera."
        case .back: "Turn so your back faces the camera."
        }
    }
}

/// Front, side and back photos for a posture check.
///
/// Photos are held in memory only: nothing is saved or uploaded.
/// Posture analysis isn't part of this yet.
@MainActor @Observable
final class PostureCaptureViewModel {
    enum Phase: Equatable {
        case idle
        case requestingAccess
        case denied
        case unavailable
        case live
        case countdown(Int)
        case capturing
        case review
        case failed(String)
        case complete
    }

    private(set) var phase: Phase = .idle
    private(set) var angle: PostureAngle = .front
    private(set) var photos: [PostureAngle: Data] = [:]
    private(set) var isUsingFrontCamera: Bool
    /// Counts down before each photo, so there's time to step back into the frame.
    var usesTimer = true

    let camera: CameraControlling
    let countdownSeconds: Int
    private let tick: Duration
    @ObservationIgnored private var captureTask: Task<Void, Never>?

    init(camera: CameraControlling, countdownSeconds: Int = 5, tick: Duration = .seconds(1)) {
        self.camera = camera
        self.countdownSeconds = countdownSeconds
        self.tick = tick
        self.isUsingFrontCamera = camera.isUsingFrontCamera
    }

    var currentPhoto: Data? { photos[angle] }

    /// Asks for camera access if needed, then starts the camera.
    func prepare() async {
        guard phase != .complete else { return }
        switch camera.access {
        case .unavailable:
            phase = .unavailable
            return
        case .denied:
            phase = .denied
            return
        case .notDetermined:
            phase = .requestingAccess
            guard await camera.requestAccess() else {
                phase = .denied
                return
            }
        case .authorized:
            break
        }
        await startCamera()
    }

    /// Stops the camera, e.g. when the screen goes away. A running countdown is cancelled.
    func stop() {
        captureTask?.cancel()
        captureTask = nil
        if case .countdown = phase {
            phase = .live
        }
        camera.stop()
    }

    func capture() {
        guard phase == .live else { return }
        captureTask = Task { await runCapture() }
    }

    func cancelCountdown() {
        guard case .countdown = phase else { return }
        captureTask?.cancel()
        captureTask = nil
        phase = .live
    }

    func retake() {
        guard phase == .review else { return }
        photos[angle] = nil
        phase = .live
    }

    /// Moves to the next angle, or finishes after the last one.
    func continueToNext() {
        guard phase == .review else { return }
        if let next = PostureAngle(rawValue: angle.rawValue + 1) {
            angle = next
            phase = .live
        } else {
            phase = .complete
            camera.stop()
        }
    }

    func startOver() async {
        photos = [:]
        angle = .front
        phase = .idle
        await prepare()
    }

    func retryAfterFailure() async {
        guard case .failed = phase else { return }
        await startCamera()
    }

    func switchCamera() async {
        guard phase == .live else { return }
        do {
            try await camera.switchCamera()
            isUsingFrontCamera = camera.isUsingFrontCamera
        } catch {
            phase = .failed("Couldn't switch cameras.")
        }
    }

    private func startCamera() async {
        do {
            try await camera.start()
            phase = currentPhoto == nil ? .live : .review
        } catch {
            phase = .failed("The camera couldn't start.")
        }
    }

    private func runCapture() async {
        if usesTimer {
            for remaining in stride(from: countdownSeconds, to: 0, by: -1) {
                phase = .countdown(remaining)
                do {
                    try await Task.sleep(for: tick)
                } catch {
                    return
                }
            }
        }
        phase = .capturing
        do {
            let data = try await camera.capturePhoto()
            photos[angle] = data
            phase = .review
        } catch {
            phase = .failed("The photo couldn't be taken.")
        }
    }
}
