import SwiftUI

struct SnippetsView: View {
    @StateObject private var store = SnippetStore()
    @State private var editingSnippet: Snippet?
    @State private var showingEditor = false

    var body: some View {
        List {
            if store.snippets.isEmpty {
                ContentUnavailableView {
                    Label("No snippets yet", systemImage: "text.badge.plus")
                } description: {
                    Text("Create shortcuts like ;sig or ;addr. Snippets stay on this device.")
                } actions: {
                    Button("Add Snippet") { addSnippet() }
                }
            } else {
                ForEach(store.snippets) { snippet in
                    Button {
                        editingSnippet = snippet
                        showingEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snippet.shortcut)
                                .font(.headline.monospaced())
                            Text(snippet.replacement)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(snippet.shortcut), \(snippet.replacement)")
                    .accessibilityHint("Double tap to edit this snippet")
                }
                .onDelete(perform: store.delete)
                .onMove(perform: store.move)
            }

            if let error = store.lastError {
                Section("Storage") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Snippets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: addSnippet) {
                    Label("Add Snippet", systemImage: "plus")
                }
            }
            if !store.snippets.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                SnippetEditorView(store: store, snippet: editingSnippet)
            }
        }
        .onAppear { store.reload() }
    }

    private func addSnippet() {
        editingSnippet = nil
        showingEditor = true
    }
}

private struct SnippetEditorView: View {
    @ObservedObject var store: SnippetStore
    let snippet: Snippet?

    @Environment(\.dismiss) private var dismiss
    @State private var shortcut = ""
    @State private var replacement = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Shortcut") {
                TextField(";shortcut", text: $shortcut)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .accessibilityLabel("Snippet shortcut")
                Text("\(shortcut.count)/\(Snippet.maximumShortcutLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Replacement") {
                TextField("Replacement text", text: $replacement, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityLabel("Snippet replacement text")
                Text("\(replacement.count)/\(Snippet.maximumReplacementLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(snippet == nil ? "New Snippet" : "Edit Snippet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard let snippet else { return }
            shortcut = snippet.shortcut
            replacement = snippet.replacement
        }
    }

    private func save() {
        let value = Snippet(
            id: snippet?.id ?? UUID(),
            shortcut: shortcut,
            replacement: replacement,
            order: snippet?.order ?? store.snippets.count
        )

        do {
            try store.save(value)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
