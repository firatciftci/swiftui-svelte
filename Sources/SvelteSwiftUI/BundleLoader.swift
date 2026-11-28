import CryptoKit
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
                Bundle(script: script, map: map?.1.statusCode == 200 ? map?.0 : nil, version: version(of: response, body: data)))
        } catch {
            return .failure(Failure(message: "Couldn't load \(source.absoluteString): \(error.localizedDescription)"))
        }
    }

    static func version(of source: URL, after previous: String?) async -> String? {
        guard !source.isFileURL else { return fileVersion(of: source) }
        guard let (data, response) = try? await fetch(source, headers: conditions(after: previous)) else { return nil }
        switch response.statusCode {
        case 304: return previous
        case 200: return version(of: response, body: data)
        default: return nil
        }
    }

    static func fileVersion(of source: URL) -> String? {
        let date = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return date.map { String($0.timeIntervalSince1970) }
    }

    private static func conditions(after previous: String?) -> [String: String] {
        guard let previous else { return [:] }
        if previous.hasPrefix("\"") || previous.hasPrefix("W/\"") { return ["If-None-Match": previous] }
        if previous.hasSuffix(" GMT") { return ["If-Modified-Since": previous] }
        return [:]
    }

    private static func validator(of response: HTTPURLResponse) -> String? {
        response.value(forHTTPHeaderField: "ETag") ?? response.value(forHTTPHeaderField: "Last-Modified")
    }

    private static func version(of response: HTTPURLResponse, body: Data) -> String {
        validator(of: response) ?? SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    }

    private static func fetch(_ url: URL, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, response)
    }
}
