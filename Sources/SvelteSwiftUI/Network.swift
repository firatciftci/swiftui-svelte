import Foundation
import JavaScriptCore

nonisolated final class NetworkClient: @unchecked Sendable {
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
        var redirected = false
    }

    private struct Socket {
        let task: URLSessionWebSocketTask
        let handlers: JSValue
        var isOpen = false
        var isClosed = false
        var expectsNoStatus = false
    }

    private let queue: DispatchQueue
    private let operations = OperationQueue()
    private let events = SessionEvents()
    private var session: URLSession?
    private var fetches: [Int: Fetch] = [:]
    private var fetchTasks: [Int: URLSessionTask] = [:]
    private var sockets: [Int: Socket] = [:]
    private var socketIDs: [Int: Int] = [:]

    init(queue: DispatchQueue) {
        self.queue = queue
        operations.underlyingQueue = queue
        operations.maxConcurrentOperationCount = 1
        events.owner = self
    }

    private var currentSession: URLSession {
        if let session { return session }
        let session = URLSession(configuration: .default, delegate: events, delegateQueue: operations)
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
        urlRequest.httpShouldHandleCookies = request.credentials != "omit"
        urlRequest.cachePolicy =
            switch request.cache {
            case "no-store", "reload", "no-cache": .reloadIgnoringLocalCacheData
            case "force-cache": .returnCacheDataElseLoad
            case "only-if-cached": .returnCacheDataDontLoad
            default: .useProtocolCachePolicy
            }
        let task = currentSession.dataTask(with: urlRequest)
        fetches[task.taskIdentifier] = Fetch(
            id: id, onResponse: callbacks.onResponse, onData: callbacks.onData, onEnd: onEnd, redirect: request.redirect)
        fetchTasks[id] = task
        task.resume()
    }

    static func failure(_ error: any Error) -> [String: Any] {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return ["message": nsError.localizedDescription, "code": nsError.code, "name": "unknown"]
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
        return ["message": nsError.localizedDescription, "code": nsError.code, "name": name]
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
        socket.task.send(message) { [weak self, queue] _ in
            guard let self else { return }
            queue.async { _ = self.sockets[id]?.handlers.invokeMethod("sent", withArguments: [count]) }
        }
    }

    func closeSocket(id: Int, code: Int?, reason: String) {
        guard var socket = sockets[id], !socket.isClosed else { return }
        socket.expectsNoStatus = code == nil
        sockets[id] = socket
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code ?? 1000) ?? .normalClosure
        socket.task.cancel(with: closeCode, reason: reason.isEmpty ? nil : Data(reason.utf8))
    }

    private func receive(_ id: Int) {
        sockets[id]?.task.receive { [weak self, queue] result in
            guard let self else { return }
            queue.async {
                guard let socket = self.sockets[id], !socket.isClosed, case .success(let message) = result
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
                self.receive(id)
            }
        }
    }

    func didReceive(_ response: URLResponse, task: URLSessionTask) {
        guard let fetch = fetches[task.taskIdentifier] else { return }
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
        let meta: [String: Any] = [
            "status": status,
            "url": response.url?.absoluteString ?? task.originalRequest?.url?.absoluteString ?? "",
            "redirected": fetch.redirected,
            "headers": headers,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: meta) else { return }
        fetch.onResponse.call(withArguments: [String(bytes: data, encoding: .utf8) ?? "{}"])
    }

    func didReceive(_ data: Data, task: URLSessionTask) {
        guard let fetch = fetches[task.taskIdentifier], let context = fetch.onData.context else { return }
        fetch.onData.call(withArguments: [context.bytes(data)])
    }

    func redirect(task: URLSessionTask, to request: URLRequest) -> URLRequest? {
        guard var fetch = fetches[task.taskIdentifier] else { return request }
        switch fetch.redirect {
        case "manual":
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
            return request
        }
    }

    func didComplete(task: URLSessionTask, error: (any Error)?) {
        if let fetch = fetches.removeValue(forKey: task.taskIdentifier) {
            fetchTasks[fetch.id] = nil
            fetch.onEnd.call(withArguments: [error.map { Self.failure($0) as Any } ?? NSNull()])
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

nonisolated private final class SessionEvents: NSObject, URLSessionDataDelegate, URLSessionWebSocketDelegate,
    @unchecked Sendable
{
    weak var owner: NetworkClient?

    func urlSession(
        _: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        owner?.didReceive(response, task: dataTask)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        owner?.didReceive(data, task: dataTask)
    }

    func urlSession(
        _: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let owner else {
            completionHandler(request)
            return
        }
        completionHandler(owner.redirect(task: task, to: request))
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        owner?.didComplete(task: task, error: error)
    }

    func urlSession(
        _: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?
    ) {
        owner?.didOpen(task: webSocketTask, protocol: `protocol`)
    }

    func urlSession(
        _: URLSession, webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
    ) {
        owner?.didClose(task: webSocketTask, code: closeCode, reason: reason)
    }
}
