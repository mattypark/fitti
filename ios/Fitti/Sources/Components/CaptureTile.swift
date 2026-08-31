import SwiftUI
import FittiDesign

/// A real captured piece in the closet grid.
///
/// Draws from the local thumbnail the instant one exists, so a tile is filled
/// within a few hundred milliseconds of the shutter — long before anything has
/// been uploaded or tagged. That optimism is the difference between an app that
/// feels instant and one that feels like it is thinking.
struct CaptureTile: View {
    let item: CaptureItem
    let palette: Palette

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(palette.groundLift)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            } else {
                BlobShape(seed: item.id.uuidString.paletteSeed, wobble: 0.18)
                    .fill(palette.groundSunk)
                    .padding(22)
            }

            if item.state != .ready {
                stateChip
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: item.thumbnailFile) { await loadThumbnail() }
        .accessibilityLabel(item.state == .ready ? "Captured piece" : "Captured piece, still processing")
    }

    private var stateChip: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Group {
                    if item.state == .failed {
                        Image(systemName: "exclamationmark")
                    } else {
                        ProgressView().controlSize(.mini)
                    }
                }
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
                .padding(8)
            }
        }
    }

    private func loadThumbnail() async {
        guard let file = item.thumbnailFile else { return }
        let url = AppGroup.url(for: file)
        // Off the main actor: decoding even a 400px image on the main thread
        // during a scroll is a dropped frame.
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        thumbnail = image
    }
}
