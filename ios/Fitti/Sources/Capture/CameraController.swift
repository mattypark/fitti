import AVFoundation
import UIKit
import Observation

/// The camera, wrapped so the view never touches AVFoundation directly.
///
/// Configuration happens on a private serial queue because
/// `AVCaptureSession.startRunning()` blocks — call it on the main thread and the
/// UI freezes for the better part of a second every time capture opens.
@Observable
@MainActor
final class CameraController: NSObject {
    private(set) var isAvailable = false
    private(set) var isReady = false
    private(set) var permissionDenied = false

    /// AVCaptureSession is not Sendable, but every mutation here is serialised
    /// onto `sessionQueue` and reads from the preview layer happen on the main
    /// thread — which is exactly the contract AVFoundation asks for. Marking it
    /// unsafe states that explicitly rather than hiding it behind a copy.
    nonisolated(unsafe) let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.fitti.camera")
    /// Same contract as `session`: configured and used only on `sessionQueue`,
    /// with delegate callbacks hopping back to the main actor.
    private nonisolated(unsafe) let output = AVCapturePhotoOutput()

    /// Called with the encoded photo. Deliberately raw `Data` straight from
    /// AVFoundation — never a UIImage, which would decode a ~48MB bitmap on the
    /// capture path for no reason.
    var onPhoto: ((Data) -> Void)?

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        // No camera in the Simulator. The shell still works: the shutter enqueues
        // a generated stand-in so the whole capture-to-closet path is exercisable.
        isAvailable = false
        #else
        isAvailable = true
        #endif
    }

    func start() async {
        guard isAvailable else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                permissionDenied = true
                return
            }
        default:
            permissionDenied = true
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configure()
            if !self.session.isRunning { self.session.startRunning() }
            Task { @MainActor in self.isReady = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture() {
        guard isReady else { return }
        let settings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: AVVideoCodecType.hevc
        ])
        output.capturePhoto(with: settings, delegate: self)
    }

    private nonisolated func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.inputs.isEmpty else { return }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else { return }

        session.addInput(input)
        session.addOutput(output)
    }
}

extension CameraController: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in onPhoto?(data) }
    }
}
