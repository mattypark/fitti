import SwiftUI
import UIKit
import FittiDesign

/// Rapid-fire capture.
///
/// Snap, snap, snap. There is no form, no name field, no category picker and no
/// save button, because the thing that kills every wardrobe app is that adding a
/// piece takes minutes. Each shot writes bytes to disk, appends one queue record,
/// and returns — everything else happens behind the sheet.
struct CaptureView: View {
    let palette: Palette
    var onCaptured: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera = CameraController()
    @State private var shots = 0
    @State private var flash = false
    @State private var problem: String?
    @State private var showLibrary = false

    var body: some View {
        ZStack {
            Fixed.ink.ignoresSafeArea()

            if camera.isReady {
                CameraPreview(session: camera.session).ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                if let problem {
                    Text(problem)
                        .font(.fittiCallout)
                        .foregroundStyle(Fixed.paper)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                } else if !camera.isAvailable {
                    Text("No camera here — the shutter still\nadds a piece so you can try the flow")
                        .font(.fittiCallout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Fixed.paper.opacity(0.6))
                }
                Spacer()
                HStack(spacing: Space.xl) {
                    libraryButton
                    shutter
                    // Balances the row so the shutter stays centred under the thumb.
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.bottom, Space.xxl)
            }

            if flash {
                Fixed.paper.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .task {
            camera.onPhoto = { data in enqueue(data) }
            await camera.start()
            if camera.permissionDenied {
                problem = "Fitti needs the camera to add clothes.\nTurn it on in Settings."
            }
        }
        .sheet(isPresented: $showLibrary) {
            LibraryImport { count in
                shots += count
                if count > 0 { onCaptured() }
            }
            .ignoresSafeArea()
        }
        .onDisappear {
            camera.stop()
            Task { await CaptureWorker.shared.drain() }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.shared.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Fixed.paper)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.squash)
            .accessibilityLabel("Back")

            Spacer()

            if shots > 0 {
                Text("\(shots) added")
                    .font(.fittiCallout)
                    .foregroundStyle(Fixed.yellow)
                    .monospacedDigit()
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.sm)
    }

    private var libraryButton: some View {
        Button { showLibrary = true } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Fixed.paper)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.squash)
        .accessibilityLabel("Add from photo library")
    }

    private var shutter: some View {
        Button {
            if camera.isAvailable {
                camera.capture()
            } else {
                enqueue(PlaceholderPhoto.make())
            }
        } label: {
            ZStack {
                JellyBlob(shape: BlobShape(seed: "shutter".paletteSeed, wobble: 0.12),
                          base: Fixed.yellowPigment,
                          glow: 26)
                Image(systemName: "camera.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Fixed.ink)
            }
            .frame(width: 92, height: 92)
        }
        .buttonStyle(.squash)
        .accessibilityLabel("Take a photo")
    }

    private func enqueue(_ data: Data) {
        Task {
            do {
                try await CaptureQueue.shared.enqueue(data, source: camera.isAvailable ? .camera : .library)
                shots += 1
                onCaptured()
                Haptics.shared.shutter()
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.06)) { flash = true }
                    withAnimation(.easeIn(duration: 0.18).delay(0.06)) { flash = false }
                }
                // Processing runs behind the sheet, so the next shot is instant.
                Task.detached { await CaptureWorker.shared.drain() }
            } catch {
                problem = "Couldn't save that one. Out of space?"
            }
        }
    }
}

/// Stand-in photo for the Simulator, where there is no camera. Lets the whole
/// capture path — enqueue, derive, thumbnail, closet tile — be exercised without
/// a device.
enum PlaceholderPhoto {
    static func make(size: Int = 1200) -> Data {
        let hue = Double.random(in: 0...360)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor(hue: hue / 360, saturation: 0.55, brightness: 0.85, alpha: 1).setFill()
            let inset = CGFloat(size) * 0.18
            UIBezierPath(ovalIn: CGRect(x: inset, y: inset,
                                        width: CGFloat(size) - inset * 2,
                                        height: CGFloat(size) - inset * 2)).fill()
        }
        return image.heicData() ?? image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}

private extension UIImage {
    func heicData() -> Data? {
        guard let cg = cgImage else { return nil }
        return ImagePipeline.encodeHEIC(cg)
    }
}
