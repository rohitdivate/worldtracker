import SwiftUI

/// Identifiable URL wrapper for `.sheet(item:)` share flows.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// The universal share flow: tap the share icon → the card renders
/// synchronously → this sheet previews the PNG with one big share button.
/// (ShareLink needs an eager URL; rendering on tap keeps scrolling free.)
struct SharePreviewSheet: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 22, y: 8)
                    .padding(.horizontal, 30)
            }
            Spacer()
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.sky)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.auroraGradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.skyRaised)
    }
}
