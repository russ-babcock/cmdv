import SwiftUI

struct PreviewOverlayView: View {
    let clip: Clip
    let onDismiss: () -> Void
    let onNavigate: (PreviewNavigationDirection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 1))
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.space) { onDismiss(); return .handled }
        .onKeyPress(.upArrow) { onNavigate(.previous); return .handled }
        .onKeyPress(.downArrow) { onNavigate(.next); return .handled }
    }

    @ViewBuilder
    private var content: some View {
        switch clip.kind {
        case .image:
            if let imagePath = clip.imagePath, let image = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                imagePlaceholder
            }
        case .text, .rtf, .html, .fileURL:
            ScrollView {
                Text(clip.plainText ?? clip.previewText)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var imagePlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if clip.kind == .image, let width = clip.pixelWidth, let height = clip.pixelHeight {
                Text("\(width)\u{00D7}\(height)")
            }
            if let byteSize = clip.byteSize {
                Text(ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file))
            }
            Spacer()
            if let sourceAppName = clip.sourceAppName {
                Text(sourceAppName)
            }
            Text(clip.createdAt, style: .date)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial)
    }
}
