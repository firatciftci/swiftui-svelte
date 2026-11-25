import Foundation

nonisolated enum BundleLoader {
    struct Bundle: Sendable {
        let script: String
        let map: Data?
        let version: String?
    }

    struct Failure: Error {
        let message: String
    }

    static func load(_ source: URL) -> Result<Bundle, Failure> {
        guard let script = try? String(contentsOf: source, encoding: .utf8) else {
            return .failure(Failure(message: "Couldn't load \(source.path(percentEncoded: false))."))
        }
        let map = try? Data(contentsOf: source.appendingPathExtension("map"))
        return .success(Bundle(script: script, map: map, version: fileVersion(of: source)))
    }

    static func download(_ source: URL) async -> Result<Bundle, Failure> {
        do {
            let (data, response) = try await fetch(source)
            guard response.statusCode == 200 else {
                return .failure(Failure(message: "Couldn't load \(source.absoluteString): the server answered \(response.statusCode)."))
            }
            guard let script = String(bytes: data, encoding: .utf8) else {
                return .failure(Failure(message: "Couldn't load \(source.absoluteString): it isn't UTF-8 text."))
            }
            let map = try? await fetch(source.appendingPathExtension("map"))
            return .success(
                Bundle(script: script, map: map?.1.statusCode == 200 ? map?.0 : nil, version: version(of: response)))
        } catch {
            return .failure(Failure(message: "Couldn't load \(source.absoluteString): \(error.localizedDescription)"))
        }
    }

    static func version(of source: URL) async -> String? {
        guard !source.isFileURL else { return fileVersion(of: source) }
        guard let (_, response) = try? await fetch(source, method: "HEAD"), response.statusCode == 200 else { return nil }
        return version(of: response)
    }

    private static func fileVersion(of source: URL) -> String? {
        let date = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return date.map { String($0.timeIntervalSince1970) }
    }

    private static func version(of response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderField: "ETag") ?? response.value(forHTTPHeaderField: "Last-Modified")
    }

    private static func fetch(_ url: URL, method: String = "GET") async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        request.httpMethod = method
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, response)
    }
}
