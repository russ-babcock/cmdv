import SwiftUI

/// The "Edit…" sheet for a text clip.
struct ClipEditorView: View {
    let clip: Clip
    let onSave: (String) -> Void

    @State private var text: String
    @FocusState private var isEditorFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(clip: Clip, onSave: @escaping (String) -> Void) {
        self.clip = clip
        self.onSave = onSave
        _text = State(initialValue: clip.plainText ?? clip.previewText)
    }

    /// Saving empty text would leave a row with nothing to show and nothing to
    /// paste; deleting the clip is the way to get rid of it.
    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmed.isEmpty && text != (clip.plainText ?? clip.previewText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Clip")
                .font(.headline)

            TextEditor(text: $text)
                .font(.system(size: 13))
                .focused($isEditorFocused)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.separator, lineWidth: 1)
                }

            if clip.payloadPath != nil {
                Label(
                    "Saving will discard this clip's formatting, so it pastes as plain text.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 460, height: 300)
        // Return has to insert a newline in a multi-line editor, so Save takes
        // ⌘Return — which `.defaultAction` maps to once the editor holds focus.
        .onAppear { isEditorFocused = true }
    }
}
