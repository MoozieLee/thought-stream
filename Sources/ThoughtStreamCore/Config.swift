import Foundation

public struct ThoughtStreamConfig: Codable, Sendable {
    public var storageRoot: String?

    private static var directoryURL: URL {
        let homeURL: URL
        if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
            homeURL = URL(fileURLWithPath: home, isDirectory: true)
        } else {
            homeURL = FileManager.default.homeDirectoryForCurrentUser
        }
        return homeURL.appendingPathComponent(".config/thoughtstream", isDirectory: true)
    }

    public static var configURL: URL {
        directoryURL.appendingPathComponent("config.json", isDirectory: false)
    }

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
