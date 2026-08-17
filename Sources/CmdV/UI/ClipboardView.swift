import SwiftUI

struct ClipboardView: View {
    private let clipStore: ClipStore
    private let preferences: Preferences
    @Bindable var model: ClipListViewModel
    @Bindable var pasteQueue: PasteQueue
    @FocusState private var isSearchFocused: Bool

    /// Driven by our own toolbar button — see `.toolbar(removing: .sidebarToggle)`.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// `formatted` is `false` for the default plain-text paste (click, Return,
    /// the plain "Paste" menu item) and `true` only for "Paste with Formatting".
    let onActivate: (Clip, Bool) -> Void
    let onPreview: (Clip) -> Void
    let onOpenSettings: () -> Void

    init(
        clipStore: ClipStore,
        preferences: Preferences,
        model: ClipListViewModel,
        pasteQueue: PasteQueue,
        onActivate: @escaping (Clip, Bool) -> Void,
        onPreview: @escaping (Clip) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.clipStore = clipStore
        self.preferences = preferences
        self.model = model
        self.pasteQueue = pasteQueue
        self.onActivate = onActivate
        self.onPreview = onPreview
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $model.sidebarFilter)
                .navigationSplitViewColumnWidth(min: 120, ideal: 140, max: 180)
                // Must sit on the sidebar column's content — applied to the
                // `NavigationSplitView` itself it silently does nothing, and
                // the built-in toggle stays alongside ours as a duplicate.
                .toolbar(removing: .sidebarToggle)
        } detail: {
            // Search lives here rather than in the toolbar. As a
            // `.searchable(placement: .toolbar)` field it expanded to eat most
            // of this 560pt panel's titlebar, which pushed every button into
            // an overflow (») menu — turning one-click actions into
            // click-into-a-menu. Sitting above the list it is always visible,
            // always one click, and leaves the toolbar with room to spare.
            //
            // No `.navigationTitle` either: SwiftUI pushes it into the
            // titlebar (overriding the panel's `titleVisibility = .hidden`)
            // and it costs width for nothing — the sidebar already shows
            // which filter is active.
            VStack(spacing: 0) {
                searchBar
                Divider()
                list
            }
        }
        .toolbar {
            // Only a handful of small items now that search is out of the
            // titlebar, so nothing collapses into an overflow menu and every
            // action stays a single click.
            ToolbarItemGroup(placement: .primaryAction) {
                // Flexible space, so the buttons pin to the window's trailing
                // edge in both sidebar states. Without it SwiftUI lays them
                // out from the leading edge of the detail column, which drags
                // them into the middle of the titlebar whenever the sidebar
                // is showing.
                Spacer()

                // Replaces the built-in sidebar toggle (removed on the
                // sidebar column above), which anchored itself to the
                // sidebar/detail boundary and so slid across the titlebar
                // whenever the sidebar opened. Ours stays in this group.
                Button {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar")

                Toggle(isOn: Binding(get: { pasteQueue.isActive }, set: { _ in pasteQueue.toggle() })) {
                    Image(systemName: "list.number")
                }
                .help("Queue Mode (\u{2318}K) \u{2014} click clips in the order you want them pasted")

                if pasteQueue.isActive {
                    Text("\(pasteQueue.pastedCount) pasted")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                        .monospacedDigit()
                        // The label is the last thing in the button group's
                        // pill, and text sits flush against that edge in a way
                        // the icons' own padding hides. Pads it back out.
                        .padding(.trailing, 6)
                    Button("Reset") { pasteQueue.reset() }
                }

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 620)
        .onKeyPress(phases: .down) { handleKeyPress($0) }
        .onChange(of: pasteQueue.isActive) { _, isActive in
            if isActive { isSearchFocused = false }
        }
        .sheet(item: $model.editingClip) { clip in
            ClipEditorView(clip: clip) { newText in
                try? clipStore.updateText(id: clip.id, to: newText)
                model.refresh()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clips", text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var list: some View {
        if model.filteredClips.isEmpty {
            ContentUnavailableView(
                model.searchText.isEmpty ? "No Clips Yet" : "No Matches",
                systemImage: "doc.on.clipboard",
                description: Text(
                    model.searchText.isEmpty
                        ? "Copy something and it will show up here."
                        : "Try a different search."
                )
            )
        } else {
            let effectiveKeys = model.effectivePinKeys
            List(model.filteredClips, selection: $model.selectedClipID) { clip in
                ClipRowView(
                    clip: clip,
                    pasteOrder: pasteQueue.order(for: clip.id),
                    effectiveKey: effectiveKeys[clip.id],
                    isLocked: clip.pinKey != nil,
                    onToggleFavorite: {
                        try? clipStore.setFavorite(id: clip.id, !clip.isFavorite)
                        model.refresh()
                    },
                    onToggleLock: {
                        let newKey = clip.pinKey == nil ? effectiveKeys[clip.id] : nil
                        try? clipStore.setPin(id: clip.id, key: newKey)
                        model.refresh()
                    }
                )
                .tag(clip.id)
                .contentShape(Rectangle())
                .onTapGesture { onActivate(clip, false) }
                .contextMenu { contextMenu(for: clip, effectiveKey: effectiveKeys[clip.id]) }
            }
            .listStyle(.inset)
            .onKeyPress(.return) {
                guard let selected = model.filteredClips.first(where: { $0.id == model.selectedClipID }) else {
                    return .ignored
                }
                onActivate(selected, false)
                return .handled
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for clip: Clip, effectiveKey: String?) -> some View {
        Button("Preview") { onPreview(clip) }
        // Only text has text to edit: an image has none, and a file clip's
        // content is a path the file itself owns, not something to retype.
        if clip.isEditable {
            Button("Edit\u{2026}") { model.editingClip = clip }
        }
        Divider()
        Button("Paste") { onActivate(clip, false) }
        Button("Paste with Formatting") { onActivate(clip, true) }
        Divider()
        Button(clip.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            try? clipStore.setFavorite(id: clip.id, !clip.isFavorite)
            model.refresh()
        }
        Menu("Lock to\u{2026}") {
            ForEach(PinKey.allowedCharacters, id: \.self) { key in
                let keyString = String(key)
                Button {
                    try? clipStore.setPin(id: clip.id, key: keyString)
                    model.refresh()
                } label: {
                    if clip.pinKey == keyString {
                        Label(keyString, systemImage: "checkmark")
                    } else {
                        Text(keyString)
                    }
                }
            }
        }
        if clip.pinKey != nil {
            Button("Unlock") {
                try? clipStore.setPin(id: clip.id, key: nil)
                model.refresh()
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            try? clipStore.delete(id: clip.id)
            model.refresh()
        }
    }

    /// Handles ⌘K (toggle queue mode), ⌘F (focus search), and Space (preview).
    /// Pin activation (bare `1`-`9`/`A`-`Z`, or ⌃+key) is handled a level
    /// lower, by `ClipboardWindowController`'s local event monitor — the
    /// underlying `NSTableView` behind this `List` consumes plain
    /// alphanumeric keystrokes for its own type-select before they'd ever
    /// reach an `.onKeyPress` handler here.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.characters == "k", press.modifiers == .command {
            pasteQueue.toggle()
            return .handled
        }

        if press.characters == "f", press.modifiers == .command, !pasteQueue.isActive {
            isSearchFocused = true
            return .handled
        }

        if press.key == .space, !isSearchFocused, press.modifiers.isEmpty {
            guard let selected = model.filteredClips.first(where: { $0.id == model.selectedClipID }) else {
                return .ignored
            }
            onPreview(selected)
            return .handled
        }

        return .ignored
    }
}
