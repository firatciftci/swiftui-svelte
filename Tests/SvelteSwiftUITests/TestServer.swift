import CryptoKit
import Foundation
import Network

nonisolated final class TestServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TestServer")
    private let listener: NWListener
    private var connections: Array<NWConnection> = []
    private var isStarted = false
    private var files: [String: String] = [:]
    private var sockets = 0

    var openSockets: Int { queue.sync { sockets } }

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, any Error>) in
            listener.stateUpdateHandler = { [self] state in
                guard !isStarted else { return }
                switch state {
                case .ready:
                    isStarted = true
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    isStarted = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                connections.append(connection)
                ServerConnection(
                    connection: connection, queue: queue, files: { [weak self] in self?.files[$0] },
                    onSocket: { [weak self] change in self?.sockets += change }
                ).start()
            }
            listener.start(queue: queue)
        }
    }

    func serve(_ text: String, at path: String) {
        queue.sync { files[path] = text }
    }

    func stop() {
        queue.sync {
            listener.cancel()
            for connection in connections { connection.forceCancel() }
            connections = []
        }
    }
}

nonisolated private final class ServerConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let files: (String) -> String?
    private let onSocket: (Int) -> Void
    private var buffer = Data()
    private var isWebSocket = false
    private var message = Data()
    private var messageOpcode: UInt8 = 0
    private var isClosing = false

    init(
        connection: NWConnection, queue: DispatchQueue, files: @escaping (String) -> String?,
        onSocket: @escaping (Int) -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.files = files
        self.onSocket = onSocket
    }

    func start() {
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            if isWebSocket { readFrames() } else { readRequest() }
            if isComplete || error != nil {
                if isWebSocket { onSocket(-1) }
                connection.cancel()
                return
            }
            receive()
        }
    }

    private func readRequest() {
        let separator = Data("\r\n\r\n".utf8)
        guard let end = buffer.range(of: separator) else { return }
        let head = (String(bytes: buffer[buffer.startIndex..<end.lowerBound], encoding: .utf8) ?? "")
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = headers[name].map { "\($0), \(value)" } ?? value
        }
        let length = Int(headers["content-length"] ?? "0") ?? 0
        guard buffer.distance(from: end.upperBound, to: buffer.endIndex) >= length else { return }
        let bodyStart = end.upperBound
        let body = Data(buffer[bodyStart..<buffer.index(bodyStart, offsetBy: length)])
        buffer = Data(buffer[buffer.index(bodyStart, offsetBy: length)...])
        route(method: String(requestLine[0]), target: String(requestLine[1]), headers: headers, body: body)
    }

    private func route(method: String, target: String, headers: [String: String], body: Data) {
        let components = URLComponents(string: "http://localhost\(target)")
        let path = components?.path ?? "/"
        let query = Dictionary(
            (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        switch path {
        case "/ws" where headers["upgrade"]?.lowercased() == "websocket":
            upgrade(headers: headers)
        case "/json":
            respond(200, ["content-type": "application/json"], Data(#"{"ok":true,"list":[1,2,3]}"#.utf8))
        case "/echo":
            let echo: [String: Any] = [
                "method": method, "path": target, "headers": headers, "body": (String(bytes: body, encoding: .utf8) ?? ""),
            ]
            respond(200, ["content-type": "application/json"], (try? JSONSerialization.data(withJSONObject: echo)) ?? Data())
        case "/mirror":
            respond(200, ["content-type": "application/octet-stream"], body)
        case "/bytes":
            let count = Int(query["n"] ?? "0") ?? 0
            respond(200, ["content-type": "application/octet-stream"], Data((0..<count).map { UInt8($0 % 256) }))
        case "/cookie":
            respond(200, ["set-cookie": "swiftui_test=kept; Path=/"], Data("ok".utf8))
        case "/redirect":
            respond(302, ["location": query["to"] ?? "/"], Data())
        case "/headers":
            respond(200, ["x-one": "1", "x-two": "two"], Data("ok".utf8))
        case "/stream":
            stream(["one\n", "two\n", "three\n"], delay: query["slow"] == nil ? 0.04 : 5)
        case "/sse":
            let chunks =
                headers["last-event-id"] == nil
                ? [
                    "retry: 10\n", ": comment\n", "id: 1\ndata: hello\n\n",
                    "event: named\r\nid: 2\r\ndata: a\rdata: b\r\n\r\n", "data: split\r", "\ndata: crlf\n\n",
                    "event: blank\ndata:\n\n", "id: 3\n\n", "data: partial",
                ] : ["data: resumed\n\n"]
            stream(chunks, delay: 0.005)
        case "/slow":
            queue.asyncAfter(deadline: .now() + 5) { [self] in respond(200, [:], Data("late".utf8)) }
        case let path where path.hasPrefix("/status/"):
            let status = Int(path.dropFirst(8)) ?? 500
            respond(status, [:], status == 204 || status == 304 ? Data() : Data("status \(status)".utf8))
        case let path where files(path) != nil:
            let body = Data((files(path) ?? "").utf8)
            let tag = "\"" + SHA256.hash(data: body).prefix(8).map { String(format: "%02x", $0) }.joined() + "\""
            let isPlain = path.hasPrefix("/plain/")
            if method == "HEAD", isPlain || path.hasPrefix("/nohead/") {
                respond(405, [:], Data())
            } else if !isPlain, headers["if-none-match"] == tag {
                respond(304, ["etag": tag], Data())
            } else {
                let validators = isPlain ? [:] : ["etag": tag]
                respond(200, validators.merging(["content-type": "text/javascript"]) { $1 }, body, sendsBody: method != "HEAD")
            }
        default:
            respond(404, [:], Data("not found".utf8))
        }
    }

    private func head(_ status: Int, _ headers: [String: String]) -> String {
        var text = "HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status).capitalized)\r\n"
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) { text += "\(name): \(value)\r\n" }
        return text + "\r\n"
    }

    private func respond(_ status: Int, _ headers: [String: String], _ body: Data, sendsBody: Bool = true) {
        var headers = headers
        headers["connection"] = "close"
        if status != 204, status != 304 { headers["content-length"] = String(body.count) }
        var data = Data(head(status, headers).utf8)
        if sendsBody { data.append(body) }
        connection.send(content: data, completion: .contentProcessed { [connection] _ in connection.cancel() })
    }

    private func stream(_ chunks: Array<String>, delay: Double) {
        let headers = ["content-type": "text/event-stream", "transfer-encoding": "chunked", "connection": "close"]
        connection.send(content: Data(head(200, headers).utf8), completion: .idempotent)
        send(chunks, from: 0, delay: delay)
    }

    private func send(_ chunks: Array<String>, from index: Int, delay: Double) {
        guard index < chunks.count else {
            connection.send(content: Data("0\r\n\r\n".utf8), completion: .contentProcessed { [connection] _ in connection.cancel() })
            return
        }
        let chunk = Data(chunks[index].utf8)
        var data = Data((String(chunk.count, radix: 16) + "\r\n").utf8)
        data.append(chunk)
        data.append(Data("\r\n".utf8))
        connection.send(content: data, completion: .idempotent)
        queue.asyncAfter(deadline: .now() + delay) { [self] in send(chunks, from: index + 1, delay: delay) }
    }

    private func upgrade(headers: [String: String]) {
        let key = headers["sec-websocket-key"] ?? ""
        let accept = Data(Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)))
            .base64EncodedString()
        var response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
        response += "Sec-WebSocket-Accept: \(accept)\r\n"
        if let first = headers["sec-websocket-protocol"]?.split(separator: ",").first {
            response += "Sec-WebSocket-Protocol: \(first.trimmingCharacters(in: .whitespaces))\r\n"
        }
        connection.send(content: Data((response + "\r\n").utf8), completion: .idempotent)
        isWebSocket = true
        onSocket(1)
        readFrames()
    }

    private func readFrames() {
        while true {
            let bytes = Array(buffer)
            guard bytes.count >= 2 else { return }
            let isFinal = bytes[0] & 0x80 != 0
            let opcode = bytes[0] & 0x0F
            let isMasked = bytes[1] & 0x80 != 0
            var length = Int(bytes[1] & 0x7F)
            var offset = 2
            if length == 126 {
                guard bytes.count >= 4 else { return }
                length = Int(bytes[2]) << 8 | Int(bytes[3])
                offset = 4
            } else if length == 127 {
                guard bytes.count >= 10 else { return }
                length = 0
                for byte in bytes[2..<10] { length = length << 8 | Int(byte) }
                offset = 10
            }
            let maskOffset = offset
            if isMasked { offset += 4 }
            guard bytes.count >= offset + length else { return }
            var payload = Array(bytes[offset..<offset + length])
            if isMasked {
                for index in payload.indices { payload[index] ^= bytes[maskOffset + index % 4] }
            }
            buffer = Data(bytes[(offset + length)...])
            handle(opcode: opcode, isFinal: isFinal, payload: Data(payload))
        }
    }

    private func handle(opcode: UInt8, isFinal: Bool, payload: Data) {
        switch opcode {
        case 0x0, 0x1, 0x2:
            if opcode != 0 { messageOpcode = opcode }
            message.append(payload)
            guard isFinal else { return }
            let data = message
            message = Data()
            if messageOpcode == 0x1, (String(bytes: data, encoding: .utf8) ?? "") == "close" {
                isClosing = true
                var close = Data([0x0F, 0xA0])
                close.append(Data("bye".utf8))
                send(opcode: 0x8, payload: close)
            } else {
                send(opcode: messageOpcode, payload: data)
            }
        case 0x8:
            if isClosing {
                connection.cancel()
            } else {
                isClosing = true
                send(opcode: 0x8, payload: payload) { [connection] in connection.cancel() }
            }
        case 0x9:
            send(opcode: 0xA, payload: payload)
        default:
            break
        }
    }

    private func send(opcode: UInt8, payload: Data, then done: (@Sendable () -> Void)? = nil) {
        var frame = Data([0x80 | opcode])
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count < 65_536 {
            frame.append(contentsOf: [126, UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)])
        } else {
            frame.append(127)
            for shift in stride(from: 56, through: 0, by: -8) { frame.append(UInt8((payload.count >> shift) & 0xFF)) }
        }
        frame.append(payload)
        connection.send(content: frame, completion: .contentProcessed { _ in done?() })
    }
}
