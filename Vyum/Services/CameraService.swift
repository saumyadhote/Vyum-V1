import AVFoundation
import Foundation

enum CameraAccess: Equatable {
    case notDetermined
    case authorized
    case denied
    /// No camera on this device, e.g. the Simulator.
    case unavailable
}

enum CameraError: LocalizedError {
    case unavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "The camera isn't available right now."
        case .captureFailed: "The photo couldn't be taken."
        }
    }
}

/// The camera used for posture photos.
protocol CameraControlling: AnyObject {
    var access: CameraAccess { get }
    /// The live session for a preview layer, or nil when there's no real camera (tests, previews).
    var previewSession: AVCaptureSession? { get }
    var isUsingFrontCamera: Bool { get }
    func requestAccess() async -> Bool
    func start() async throws
    func stop()
    func switchCamera() async throws
    /// A JPEG/HEIC photo, oriented upright and mirrored to match the preview.
    func capturePhoto() async throws -> Data
}

/// AVFoundation camera. Starts on the front camera, so the person can see themselves
/// with the phone propped up. Nothing is saved or uploaded; photos are returned as data.
final class CameraService: CameraControlling {
    private let graph = CaptureGraph()
    private(set) var isUsingFrontCamera = true

    var previewSession: AVCaptureSession? { graph.session }

    var access: CameraAccess {
        guard CaptureGraph.device(front: true) != nil || CaptureGraph.device(front: false) != nil else {
            return .unavailable
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start() async throws {
        let front = isUsingFrontCamera
        try await graph.perform { graph in
            if !graph.isConfigured {
                try graph.configure(front: front)
            }
            if !graph.session.isRunning {
                graph.session.startRunning()
            }
        }
    }

    func stop() {
        graph.queue.async { [graph] in
            if graph.session.isRunning {
                graph.session.stopRunning()
            }
        }
    }

    func switchCamera() async throws {
        let front = !isUsingFrontCamera
        try await graph.perform { graph in
            graph.session.beginConfiguration()
            defer { graph.session.commitConfiguration() }
            try graph.useCamera(front: front)
            graph.orientConnection(front: front)
        }
        isUsingFrontCamera = front
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            graph.queue.async { [graph] in
                graph.capture(resumingWith: continuation)
            }
        }
    }
}

/// Owns the capture graph. Only touched on `queue`, hence unchecked Sendable.
nonisolated private final class CaptureGraph: @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "gogo.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private(set) var isConfigured = false

    static func device(front: Bool) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back)
    }

    /// Runs `work` on the camera queue and returns its result.
    func perform(_ work: @escaping @Sendable (CaptureGraph) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                continuation.resume(with: Result { try work(self) })
            }
        }
    }

    func configure(front: Bool) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        try useCamera(front: front)
        guard session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
        session.addOutput(photoOutput)
        orientConnection(front: front)
        isConfigured = true
    }

    func useCamera(front: Bool) throws {
        guard let device = Self.device(front: front) else { throw CameraError.unavailable }
        let newInput = try AVCaptureDeviceInput(device: device)
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else {
            // Put the old camera back so the session keeps working.
            if let input, session.canAddInput(input) {
                session.addInput(input)
            }
            throw CameraError.unavailable
        }
        session.addInput(newInput)
        input = newInput
    }

    /// Portrait photos, mirrored on the front camera so they match the preview.
    func orientConnection(front: Bool) {
        guard let connection = photoOutput.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = front
        }
    }

    func capture(resumingWith continuation: CheckedContinuation<Data, Error>) {
        // Capturing without an active connection raises an exception, so check first.
        guard session.isRunning, photoOutput.connection(with: .video)?.isActive == true else {
            continuation.resume(throwing: CameraError.unavailable)
            return
        }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: PhotoDelegate(continuation: continuation))
    }
}

/// Bridges one photo capture to async/await.
nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, Error>?
    /// The photo output doesn't retain its delegate, so keep this alive until the photo arrives.
    private var keepAlive: PhotoDelegate?

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
        super.init()
        keepAlive = self
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        defer {
            continuation = nil
            keepAlive = nil
        }
        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CameraError.captureFailed)
        }
    }
}
