import Foundation

@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var snippets: [Snippet] = []
    @Published var lastError: String?

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        reload()
    }

    func reload() {
        lastError = nil
        guard let url = SnippetStorage.fileURL(fileManager: fileManager) else {
            snippets = []
            lastError = "Shared storage is unavailable. Check the MAYA TYPE App Group capability."
            return
        }

        guard fileManager.fileExists(atPath: url.path) else {
            snippets = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            snippets = normalize(try decoder.decode([Snippet].self, from: data))
        } catch {
            snippets = []
            preserveCorruptFile(at: url)
            lastError = "Saved snippets could not be read. The original file was preserved for recovery."
        }
    }

    func save(_ snippet: Snippet) throws {
        try SnippetValidator.validate(snippet, among: snippets)

        var next = snippets
        if let index = next.firstIndex(where: { $0.id == snippet.id }) {
            next[index] = snippet
        } else {
            next.append(snippet)
        }

        try persist(normalize(next))
    }

    func delete(at offsets: IndexSet) {
        var next = snippets
        next.remove(atOffsets: offsets)
        reindexAndPersist(next)
    }

    func move(from source: IndexSet, to destination: Int) {
        var next = snippets
        next.move(fromOffsets: source, toOffset: destination)
        reindexAndPersist(next)
    }

    private func reindexAndPersist(_ values: [Snippet]) {
        let reindexed = values.enumerated().map { index, item in
            Snippet(id: item.id, shortcut: item.shortcut, replacement: item.replacement, order: index)
        }

        do {
            try persist(reindexed)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func persist(_ values: [Snippet]) throws {
        guard let url = SnippetStorage.fileURL(fileManager: fileManager) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [
                NSLocalizedDescriptionKey: "Shared storage is unavailable. Check the MAYA TYPE App Group capability."
            ])
        }

        let data = try encoder.encode(values)
        try data.write(to: url, options: .atomic)
        snippets = values
        lastError = nil
    }

    private func normalize(_ values: [Snippet]) -> [Snippet] {
        values
            .sorted {
                if $0.order == $1.order {
                    return $0.shortcut.localizedCaseInsensitiveCompare($1.shortcut) == .orderedAscending
                }
                return $0.order < $1.order
            }
            .enumerated()
            .map { index, item in
                Snippet(id: item.id, shortcut: item.shortcut, replacement: item.replacement, order: index)
            }
    }

    private func preserveCorruptFile(at url: URL) {
        let backup = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? fileManager.copyItem(at: url, to: backup)
    }
}
