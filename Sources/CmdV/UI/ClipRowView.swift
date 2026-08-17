import SwiftUI

struct ClipRowView: View {
    let clip: Clip
    var pasteOrder: Int? = nil
    /// The key shown for this row right now — locked (persisted) or just this
    /// row's current position in the auto-numbered sequence.
    var effectiveKey: String? = nil
    var isLocked: Bool = false
    var onToggleFavorite: () -> Void = {}
    var onToggleLock: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                if let pasteOrder {
                    HStack(spacing: 1) {
                        Image(systemName: "checkmark")
                        Text("\(pasteOrder)")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .frame(height: 15)
                    .background(Capsule().fill(.green))
                    .offset(x: 8, y: -5)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                titleLine

                if clip.sourceAppName != nil || clip.isConcealed {
                    HStack(spacing: 6) {
                        if let sourceAppName = clip.sourceAppName {
                            HStack(spacing: 4) {
                                if let bundleID = clip.sourceBundleID,
                                   let icon = AppIconCache.icon(forBundleID: bundleID) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 11, height: 11)
                                }
                                Text(sourceAppName)
                            }
                        }
                        if clip.isConcealed, let expiresAt = clip.expiresAt {
                            Label {
                                Text(expiresAt, style: .timer)
                            } icon: {
                                Image(systemName: "lock.fill")
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                if let effectiveKey {
                    Button(action: onToggleLock) {
                        Text(effectiveKey)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isLocked ? .white : .secondary)
                            .frame(width: 16, height: 16)
                            .background {
                                if isLocked {
                                    Circle().fill(.tint)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(isLocked ? "Locked to \(effectiveKey) \u{2014} click to unlock" : "Click to lock this clip to \(effectiveKey)")
                }
                Button(action: onToggleFavorite) {
                    Image(systemName: clip.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(clip.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .opacity(clip.isFavorite ? 1 : 0.35)
            }
        }
        .padding(.vertical, 4)
        .opacity(pasteOrder == nil ? 1 : 0.5)
    }

    /// The main line of a row. Text clips show their own content, so it reads
    /// as content; an image clip has no text of its own and its line is really
    /// a description of the picture, so it is styled as metadata instead.
    @ViewBuilder
    private var titleLine: some View {
        if clip.kind == .image {
            HStack(spacing: 5) {
                Image(systemName: "photo")
                    .font(.system(size: 10, weight: .semibold))
                Text(imageDescription)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } else {
            Text(clip.previewText)
                .lineLimit(2)
                .font(.system(size: 13))
                .foregroundStyle(detectedURL != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .underline(detectedURL != nil)
        }
    }

    private var imageDescription: String {
        guard let width = clip.pixelWidth, let height = clip.pixelHeight else {
            return clip.previewText
        }
        return "\(width) \u{00D7} \(height)"
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch clip.kind {
        case .image:
            if let thumbPath = clip.thumbPath, let image = NSImage(contentsOfFile: thumbPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    }
            } else {
                placeholderIcon("photo")
            }
        case .fileURL:
            placeholderIcon("doc")
        case .text, .rtf, .html:
            placeholderIcon("doc.text")
        }
    }

    private func placeholderIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
    }

    /// A clip whose entire text content is a single http(s) link — as opposed
    /// to a clip that merely mentions a URL somewhere in a longer text — is
    /// treated as a link for row styling purposes.
    private var detectedURL: URL? {
        guard clip.kind == .text,
              let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }
}
