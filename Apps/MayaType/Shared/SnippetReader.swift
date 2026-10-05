import Foundation

enum SnippetStorage {
    static let appGroupIdentifier = "group.com.leandrofajardo.maya-type"
    static let fileName = "maya-snippets.json"

    static func fileURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

struct SnippetReader: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> [Snippet] {
        guard let url = SnippetStorage.fileURL(fileManager: fileManager),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return []
        }

        return decoded.sorted {
            if $0.order == $1.order {
                return $0.shortcut.localizedCaseInsensitiveCompare($1.shortcut) == .orderedAscending
            }
            return $0.order < $1.order
        }
    }
}
