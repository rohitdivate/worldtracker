import SwiftUI

/// Any designed card view → a share-ready PNG. The one rasterization path
/// for Wrapped, celebrations, months, the world map, and trip postcards.
@MainActor
enum ShareCardService {
    /// ImageRenderer at `scale`, PNG into tmp. nil on renderer failure.
    static func render(
        _ view: some View,
        name: String,
        scale: CGFloat = 3,
        opaque: Bool = true
    ) -> URL? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = opaque
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).png")
        try? FileManager.default.removeItem(at: url)
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
