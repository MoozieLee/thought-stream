import Foundation

public struct ThoughtStreamConfig: Codable, Sendable {
    public var storageRoot: String?

    private static let directoryURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/thoughtstream", isDirectory: true)
    }()

    public static let configURL: URL = {
        directoryURL.appendingPathComponent("config.json", isDirectory: false)
    }()

    public static func load() -> ThoughtStreamConfig {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(ThoughtStreamConfig.self, from: data)
        else {
            return ThoughtStreamConfig()
        }
        return config
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: Self.configURL, options: .atomic)
    }

    public var resolvedStorageRoot: URL? {
        guard let root = storageRoot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !root.isEmpty
        else { return nil }
        return URL(fileURLWithPath: root, isDirectory: true)
    }
}
