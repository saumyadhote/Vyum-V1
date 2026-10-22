import AVFoundation
import Foundation
import Testing
@testable import Vyum

/// A camera that never touches hardware.
final class MockCamera: CameraControlling {
    var access: CameraAccess
    var grantsAccess: Bool
    var failsToStart = false
    var failsCapture = false
    private(set) var isRunning = false
    private(set) var isUsingFrontCamera = true
    private(set) var captureCount = 0

    var previewSession: AVCaptureSession? { nil }

    init(access: CameraAccess = .authorized, grantsAccess: Bool = true) {
        self.access = access
        self.grantsAccess = grantsAccess
    }

    func requestAccess() async -> Bool {
        access = grantsAccess ? .authorized : .denied
        return grantsAccess
    }

    func start() async throws {
        if failsToStart { throw CameraError.unavailable }
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func switchCamera() async throws {
        isUsingFrontCamera.toggle()
    }

    func capturePhoto() async throws -> Data {
        if failsCapture { throw CameraError.captureFailed }
        captureCount += 1
        return Data("photo-\(captureCount)".utf8)
    }
}

@MainActor
struct PostureCaptureViewModelTests {
    private func makeViewModel(_ camera: MockCamera = MockCamera()) -> PostureCaptureViewModel {
        PostureCaptureViewModel(camera: camera, countdownSeconds: 3, tick: .milliseconds(1))
    }

    /// Waits for a capture started with `capture()` to settle.
    private func settle(_ viewModel: PostureCaptureViewModel) async throws {
        for _ in 0..<200 {
            if viewModel.phase == .review || isFailed(viewModel.phase) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func isFailed(_ phase: PostureCaptureViewModel.Phase) -> Bool {
        if case .failed = phase { return true }
        return false
    }

    @Test("with access, preparing starts the camera live on the front angle")
    func prepareAuthorized() async {
        let camera = MockCamera()
        let viewModel = makeViewModel(camera)
        await viewModel.prepare()
        #expect(viewModel.phase == .live)
        #expect(viewModel.angle == .front)
        #expect(camera.isRunning)
    }

    @Test("asks for access the first time, and goes live when granted")
    func requestsAccess() async {
        let viewModel = makeViewModel(MockCamera(access: .notDetermined, grantsAccess: true))
        await viewModel.prepare()
        #expect(viewModel.phase == .live)
    }

    @Test("refused access shows the denied state")
    func accessRefused() async {
        let camera = MockCamera(access: .notDetermined, grantsAccess: false)
        let viewModel = makeViewModel(camera)
        await viewModel.prepare()
        #expect(viewModel.phase == .denied)
        #expect(!camera.isRunning)
    }

    @Test("previously denied access doesn't prompt again")
    func previouslyDenied() async {
        let viewModel = makeViewModel(MockCamera(access: .denied))
        await viewModel.prepare()
        #expect(viewModel.phase == .denied)
    }

    @Test("no camera shows the unavailable state")
    func unavailable() async {
        let viewModel = makeViewModel(MockCamera(access: .unavailable))
        await viewModel.prepare()
        #expect(viewModel.phase == .unavailable)
    }

    @Test("a camera that fails to start shows an error, and can be retried")
    func startFailure() async {
        let camera = MockCamera()
        camera.failsToStart = true
        let viewModel = makeViewModel(camera)
        await viewModel.prepare()
        #expect(isFailed(viewModel.phase))

        camera.failsToStart = false
        await viewModel.retryAfterFailure()
        #expect(viewModel.phase == .live)
    }

    @Test("the timer counts down, then takes the photo for review")
    func countdownThenCapture() async throws {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.capture()
        #expect(viewModel.phase == .live || viewModel.phase == .countdown(3), "Capture starts asynchronously")
        try await settle(viewModel)
        #expect(viewModel.phase == .review)
        #expect(viewModel.currentPhoto != nil)
    }

    @Test("with the timer off, the photo is taken straight away")
    func noTimer() async throws {
        let camera = MockCamera()
        let viewModel = PostureCaptureViewModel(camera: camera, countdownSeconds: 3, tick: .seconds(60))
        viewModel.usesTimer = false
        await viewModel.prepare()
        viewModel.capture()
        try await settle(viewModel)
        #expect(viewModel.phase == .review)
    }

    @Test("cancelling the countdown returns to live without a photo")
    func cancelCountdown() async throws {
        let camera = MockCamera()
        let viewModel = PostureCaptureViewModel(camera: camera, countdownSeconds: 3, tick: .seconds(60))
        await viewModel.prepare()
        viewModel.capture()
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.phase == .countdown(3))

        viewModel.cancelCountdown()
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.phase == .live)
        #expect(camera.captureCount == 0)
    }

    @Test("retake discards the photo and goes back to live")
    func retake() async throws {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.capture()
        try await settle(viewModel)

        viewModel.retake()
        #expect(viewModel.phase == .live)
        #expect(viewModel.currentPhoto == nil)
        #expect(viewModel.angle == .front)
    }

    @Test("continue walks front, side, back, then completes and stops the camera")
    func fullFlow() async throws {
        let camera = MockCamera()
        let viewModel = makeViewModel(camera)
        await viewModel.prepare()

        for expected in PostureAngle.allCases {
            #expect(viewModel.angle == expected)
            viewModel.capture()
            try await settle(viewModel)
            viewModel.continueToNext()
        }

        #expect(viewModel.phase == .complete)
        #expect(viewModel.photos.count == 3)
        #expect(!camera.isRunning)
    }

    @Test("continue does nothing until there is a photo to keep")
    func continueNeedsPhoto() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        viewModel.continueToNext()
        #expect(viewModel.angle == .front)
        #expect(viewModel.phase == .live)
    }

    @Test("a failed capture shows an error")
    func captureFailure() async throws {
        let camera = MockCamera()
        camera.failsCapture = true
        let viewModel = makeViewModel(camera)
        await viewModel.prepare()
        viewModel.capture()
        try await settle(viewModel)
        #expect(isFailed(viewModel.phase))
    }

    @Test("start over clears every photo and returns to the front angle")
    func startOver() async throws {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        for _ in PostureAngle.allCases {
            viewModel.capture()
            try await settle(viewModel)
            viewModel.continueToNext()
        }

        await viewModel.startOver()
        #expect(viewModel.photos.isEmpty)
        #expect(viewModel.angle == .front)
        #expect(viewModel.phase == .live)
    }

    @Test("switching cameras updates which camera is in use")
    func switchCamera() async {
        let viewModel = makeViewModel()
        await viewModel.prepare()
        #expect(viewModel.isUsingFrontCamera)
        await viewModel.switchCamera()
        #expect(!viewModel.isUsingFrontCamera)
    }

    @Test("leaving the screen cancels a countdown and stops the camera")
    func stopDuringCountdown() async throws {
        let camera = MockCamera()
        let viewModel = PostureCaptureViewModel(camera: camera, countdownSeconds: 3, tick: .seconds(60))
        await viewModel.prepare()
        viewModel.capture()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.stop()
        #expect(viewModel.phase == .live)
        #expect(!camera.isRunning)
        #expect(camera.captureCount == 0)
    }
}
