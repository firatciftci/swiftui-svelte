import Foundation

nonisolated final class LocalStorage: @unchecked Sendable {
    private let domain: String
    private let defaults: UserDefaults
    private var known: [String: String] = [:]

    init(name: String) {
        domain = Self.domain(for: name)
        defaults = UserDefaults(suiteName: domain) ?? .standard
    }

    static func domain(for name: String) -> String {
        "SvelteSwiftUI.localStorage.\(name)"
    }

    func load() -> String {
        known = (UserDefaults.standard.persistentDomain(forName: domain) ?? [:]).compactMapValues { $0 as? String }
        guard let data = try? JSONEncoder().encode(known) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    func save(_ json: String) {
        guard let items = try? JSONDecoder().decode([String: String].self, from: Data(json.utf8)) else { return }
        for (key, value) in items where known[key] != value { defaults.set(value, forKey: key) }
        for key in known.keys where items[key] == nil { defaults.removeObject(forKey: key) }
        known = items
    }
}

extension SvelteRuntime {
    public nonisolated static func storageName(for source: URL) -> String {
        let name = source.deletingPathExtension().lastPathComponent
        return name.isEmpty || name == "/" ? "app" : name
    }

    public nonisolated static func clearStorage(_ name: String) {
        UserDefaults.standard.removePersistentDomain(forName: LocalStorage.domain(for: name))
    }
}
