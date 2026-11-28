import Foundation
import JavaScriptCore

nonisolated final class NetworkClient {
    private struct FetchRequest: Decodable {
        let url: String
        let method: String
        let headers: Array<Array<String>>
        let redirect: String
        let credentials: String
        let cache: String
    }

    private struct Fetch {
        let id: Int
        let onResponse: JSValue
        let onData: JSValue
        let onEnd: JSValue
        let redirect: String
        let credentials: String
        var redirected = false
        var isOpaqueRedirect = false
    }

    private struct Socket {
        let task: URLSessionWebSocketTask
        let handlers: JSValue
        var isOpen = false
        var isClosed = false
        var expectsNoStatus = false
    }

    private let operations = OperationQueue()
    weak var engine: ScriptEngine?
    private var session: URLSession?
    private var fetches: [Int: Fetch] = [:]
    private var fetchTasks: [Int: URLSessionTask] = [:]
    private var sockets: [Int: Socket] = [:]
    private var socketIDs: [Int: Int] = [:]
    var origin: String?

    init() {
        operations.maxConcurrentOperationCount = 1
    }

    private var currentSession: URLSession {
        if let session { return session }
        let session = URLSession(configuration: .default, delegate: SessionEvents(engine: engine), delegateQueue: operations)
        self.session = session
        return session
    }

    func reset() {
        session?.invalidateAndCancel()
        session = nil
        fetches = [:]
        fetchTasks = [:]
        sockets = [:]
        socketIDs = [:]
    }

    struct FetchCallbacks {
        let onResponse: JSValue
        let onData: JSValue
        let onEnd: JSValue
    }

    func fetch(id: Int, json: String, body: JSValue, callbacks: FetchCallbacks) {
        let onEnd = callbacks.onEnd
        guard let request = try? JSONDecoder().decode(FetchRequest.self, from: Data(json.utf8)),
            let url = URL(string: request.url)
        else {
            onEnd.call(withArguments: [["message": "Invalid request"]])
            return
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        for pair in request.headers where pair.count == 2 {
            urlRequest.addValue(pair[1], forHTTPHeaderField: pair[0])
        }
        urlRequest.httpBody = body.bytes
        urlRequest.httpShouldHandleCookies = Self.sendsCookies(request.credentials, to: url, from: origin)
        urlRequest.cachePolicy =
            switch request.cache {
            case "no-store", "reload", "no-cache": .reloadIgnoringLocalCacheData
            case "force-cache": .returnCacheDataElseLoad
            case "only-if-cached": .returnCacheDataDontLoad
            default: .useProtocolCachePolicy
            }
        let task = currentSession.dataTask(with: urlRequest)
        fetches[task.taskIdentifier] = Fetch(
            id: id, onResponse: callbacks.onResponse, onData: callbacks.onData, onEnd: onEnd, redirect: request.redirect,
            credentials: request.credentials)
        fetchTasks[id] = task
        task.resume()
    }

    static func origin(of url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            let host = url.host(percentEncoded: false)?.lowercased()
        else { return nil }
        return "\(scheme)://\(host):\(url.port ?? (scheme == "https" ? 443 : 80))"
    }

    static func sendsCookies(_ credentials: String, to url: URL?, from origin: String?) -> Bool {
        switch credentials {
        case "omit": false
        case "include": true
        default: origin != nil && url.flatMap(Self.origin(of:)) == origin
        }
    }

    static func failure(_ error: any Error) -> JSONValue {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return ["message": .string(nsError.localizedDescription), "code": .number(Double(nsError.code)), "name": "unknown"]
        }
        let name =
            switch URLError.Code(rawValue: nsError.code) {
            case .cannotConnectToHost: "cannotConnectToHost"
            case .cannotFindHost: "cannotFindHost"
            case .networkConnectionLost: "networkConnectionLost"
            case .notConnectedToInternet: "notConnectedToInternet"
            case .dnsLookupFailed: "dnsLookupFailed"
            case .timedOut: "timedOut"
            case .cancelled: "cancelled"
            default: "unknown"
            }
        return ["message": .string(nsError.localizedDescription), "code": .number(Double(nsError.code)), "name": .string(name)]
    }

    func cancelFetch(id: Int) {
        guard let task = fetchTasks.removeValue(forKey: id) else { return }
        fetches[task.taskIdentifier] = nil
        task.cancel()
    }

    func openSocket(id: Int, url: String, protocols: String, handlers: JSValue) {
        let list = (try? JSONDecoder().decode(Array<String>.self, from: Data(protocols.utf8))) ?? []
        guard let url = URL(string: url) else {
            handlers.invokeMethod("error", withArguments: ["Invalid URL"])
            handlers.invokeMethod("close", withArguments: [1006, "", false])
            return
        }
        let task = currentSession.webSocketTask(with: url, protocols: list)
        sockets[id] = Socket(task: task, handlers: handlers)
        socketIDs[task.taskIdentifier] = id
        task.resume()
    }

    func send(id: Int, data: JSValue) {
        guard let socket = sockets[id], socket.isOpen else { return }
        let message: URLSessionWebSocketTask.Message
        let count: Int
        if let bytes = data.bytes {
            message = .data(bytes)
            count = bytes.count
        } else {
            let text = data.toString() ?? ""
            message = .string(text)
            count = text.utf8.count
        }
        let engine = engine
        socket.task.send(message) { _ in
            engine?.async { $0.network.sent(count, on: id) }
        }
    }

    private func sent(_ count: Int, on id: Int) {
        _ = sockets[id]?.handlers.invokeMethod("sent", withArguments: [count])
    }

    func closeSocket(id: Int, code: Int?, reason: String) {
        guard var socket = sockets[id], !socket.isClosed else { return }
        socket.expectsNoStatus = code == nil
        sockets[id] = socket
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code ?? 1000) ?? .normalClosure
        socket.task.cancel(with: closeCode, reason: reason.isEmpty ? nil : Data(reason.utf8))
    }

    private func receive(_ id: Int) {
        let engine = engine
        sockets[id]?.task.receive { result in
            engine?.async { $0.network.received(result, on: id) }
        }
    }

    func received(_ result: Result<URLSessionWebSocketTask.Message, any Error>, on id: Int) {
        guard let socket = sockets[id], !socket.isClosed, case .success(let message) = result
        else { return }
        switch message {
        case .string(let text):
            socket.handlers.invokeMethod("message", withArguments: [text])
        case .data(let data):
            if let context = socket.handlers.context {
                socket.handlers.invokeMethod("message", withArguments: [context.bytes(data)])
            }
        @unknown default:
            break
        }
        receive(id)
    }

    func didReceive(_ response: URLResponse, task: URLSessionTask) {
        guard let fetch = fetches[task.taskIdentifier] else { return }
        if fetch.isOpaqueRedirect {
            let meta = ResponseMeta(
                status: 0, type: "opaqueredirect", url: task.originalRequest?.url?.absoluteString ?? "", redirected: false, headers: [])
            fetch.onResponse.call(withArguments: [meta.json])
            return
        }
        var headers: Array<Array<String>> = []
        let status: Int
        if let response = response as? HTTPURLResponse {
            status = response.statusCode
            for (name, value) in response.allHeaderFields {
                headers.append([String(describing: name).lowercased(), String(describing: value)])
            }
        } else {
            status = 200
            if let type = response.mimeType {
                headers.append(["content-type", type + (response.textEncodingName.map { ";charset=\($0)" } ?? "")])
            }
            if response.expectedContentLength >= 0 {
                headers.append(["content-length", String(response.expectedContentLength)])
            }
        }
        let meta = ResponseMeta(
            status: status, type: nil, url: response.url?.absoluteString ?? task.originalRequest?.url?.absoluteString ?? "",
            redirected: fetch.redirected, headers: headers)
        fetch.onResponse.call(withArguments: [meta.json])
    }

    func didReceive(_ data: Data, task: URLSessionTask) {
        guard let fetch = fetches[task.taskIdentifier], !fetch.isOpaqueRedirect, let context = fetch.onData.context else { return }
        fetch.onData.call(withArguments: [context.bytes(data)])
    }

    func redirect(task: URLSessionTask, to request: URLRequest) -> URLRequest? {
        guard var fetch = fetches[task.taskIdentifier] else { return request }
        switch fetch.redirect {
        case "manual":
            fetch.isOpaqueRedirect = true
            fetches[task.taskIdentifier] = fetch
            return nil
        case "error":
            fetches[task.taskIdentifier] = nil
            fetchTasks[fetch.id] = nil
            fetch.onEnd.call(withArguments: [["message": "unexpected redirect"]])
            task.cancel()
            return nil
        default:
            fetch.redirected = true
            fetches[task.taskIdentifier] = fetch
            var request = request
            request.httpShouldHandleCookies = Self.sendsCookies(fetch.credentials, to: request.url, from: origin)
            return request
        }
    }

    func didComplete(task: URLSessionTask, error: (any Error)?) {
        if let fetch = fetches.removeValue(forKey: task.taskIdentifier) {
            fetchTasks[fetch.id] = nil
            fetch.onEnd.call(withArguments: [error.map { Self.failure($0).object } ?? NSNull()])
            return
        }
        guard let id = socketIDs.removeValue(forKey: task.taskIdentifier), var socket = sockets[id] else { return }
        sockets[id] = nil
        guard !socket.isClosed else { return }
        socket.isClosed = true
        socket.handlers.invokeMethod("error", withArguments: [error?.localizedDescription ?? "The connection closed"])
        socket.handlers.invokeMethod("close", withArguments: [1006, "", false])
    }

    func didOpen(task: URLSessionWebSocketTask, protocol name: String?) {
        guard let id = socketIDs[task.taskIdentifier], var socket = sockets[id] else { return }
        socket.isOpen = true
        sockets[id] = socket
        socket.handlers.invokeMethod("open", withArguments: [name ?? ""])
        receive(id)
    }

    func didClose(task: URLSessionWebSocketTask, code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard let id = socketIDs[task.taskIdentifier], var socket = sockets[id], !socket.isClosed else { return }
        socket.isClosed = true
        sockets[id] = socket
        let text = reason.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
        let status = socket.expectsNoStatus && code == .normalClosure && text.isEmpty ? 1005 : code.rawValue
        socket.handlers.invokeMethod("close", withArguments: [status, text, true])
    }
}

nonisolated private final class SessionEvents: NSObject, URLSessionDataDelegate, URLSessionWebSocketDelegate, Sendable {
    private weak let engine: ScriptEngine?

    init(engine: ScriptEngine?) {
        self.engine = engine
    }

    func urlSession(
        _: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        engine?.async { $0.network.didReceive(response, task: dataTask) }
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        engine?.async { $0.network.didReceive(data, task: dataTask) }
    }

    func urlSession(
        _: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let engine else {
            completionHandler(request)
            return
        }
        engine.async { completionHandler($0.network.redirect(task: task, to: request)) }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        engine?.async { $0.network.didComplete(task: task, error: error) }
    }

    func urlSession(
        _: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?
    ) {
        engine?.async { $0.network.didOpen(task: webSocketTask, protocol: `protocol`) }
    }

    func urlSession(
        _: URLSession, webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
    ) {
        engine?.async { $0.network.didClose(task: webSocketTask, code: closeCode, reason: reason) }
    }
}

nonisolated private struct ResponseMeta: Encodable {
    let status: Int
    let type: String?
    let url: String
    let redirected: Bool
    let headers: Array<Array<String>>

    var json: String {
        (try? BridgeJSON.encoder().encode(self)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
    }
}
