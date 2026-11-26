import type { IncomingMessage, ServerResponse } from "node:http";
import type { AddressInfo, Socket } from "node:net";
import type * as WS from "ws";
import { Buffer } from "node:buffer";
import { createServer } from "node:http";
import { createRequire } from "node:module";

const { WebSocketServer } = createRequire(import.meta.url)("ws") as typeof WS;

async function read(request: IncomingMessage): Promise<Buffer> {
  const chunks: Array<Buffer> = [];
  for await (const chunk of request) chunks.push(chunk as Buffer);
  return Buffer.concat(chunks);
}

async function wait(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function handle(
  request: IncomingMessage,
  response: ServerResponse,
): Promise<void> {
  const url = new URL(request.url ?? "/", "http://localhost");
  const body = await read(request);
  switch (url.pathname) {
    case "/json": {
      response
        .writeHead(200, { "content-type": "application/json" })
        .end('{"ok":true,"list":[1,2,3]}');
      break;
    }
    case "/echo": {
      const headers: Record<string, string> = {};
      for (const [name, value] of Object.entries(request.headers))
        headers[name] = String(value);
      response
        .writeHead(200, { "content-type": "application/json" })
        .end(
          JSON.stringify({
            method: request.method,
            path: request.url,
            headers,
            body: body.toString("utf8"),
          }),
        );
      break;
    }
    case "/mirror": {
      response
        .writeHead(200, { "content-type": "application/octet-stream" })
        .end(body);
      break;
    }
    case "/bytes": {
      const bytes = Buffer.alloc(Number(url.searchParams.get("n") ?? "0"));
      for (let index = 0; index < bytes.length; index++)
        bytes[index] = index % 256;
      response
        .writeHead(200, { "content-type": "application/octet-stream" })
        .end(bytes);
      break;
    }
    case "/cookie": {
      response
        .writeHead(200, { "set-cookie": "swiftui_test=kept; Path=/" })
        .end("ok");
      break;
    }
    case "/redirect": {
      response
        .writeHead(302, { location: url.searchParams.get("to") ?? "/" })
        .end();
      break;
    }
    case "/headers": {
      response.writeHead(200, { "x-one": "1", "x-two": "two" }).end("ok");
      break;
    }
    case "/stream": {
      response.writeHead(200, { "content-type": "text/event-stream" });
      response.flushHeaders();
      for (const line of ["one\n", "two\n", "three\n"]) {
        response.write(line);
        await wait(url.searchParams.has("slow") ? 5000 : 40);
        if (response.destroyed) return;
      }
      response.end();
      break;
    }
    case "/sse": {
      response.writeHead(200, { "content-type": "text/event-stream" });
      response.flushHeaders();
      const chunks =
        request.headers["last-event-id"] == null
          ? [
              "retry: 10\n",
              ": comment\n",
              "id: 1\ndata: hello\n\n",
              "event: named\r\nid: 2\r\ndata: a\rdata: b\r\n\r\n",
              "data: split\r",
              "\ndata: crlf\n\n",
              "event: blank\ndata:\n\n",
              "id: 3\n\n",
              "data: partial",
            ]
          : ["data: resumed\n\n"];
      for (const chunk of chunks) {
        response.write(chunk);
        await wait(5);
        if (response.destroyed) return;
      }
      response.end();
      break;
    }
    case "/slow": {
      await wait(5000);
      if (!response.destroyed) response.writeHead(200).end("late");
      break;
    }
    default: {
      if (url.pathname.startsWith("/status/")) {
        const status = Number(url.pathname.slice(8));
        response.writeHead(status);
        response.end(
          status === 204 || status === 304
            ? undefined
            : `status ${String(status)}`,
        );
      } else {
        response.writeHead(404).end("not found");
      }
    }
  }
}

export async function startServer(): Promise<{
  http: string;
  ws: string;
  close: () => Promise<void>;
}> {
  const sockets = new Set<Socket>();
  const server = createServer(
    (request, response) => void handle(request, response),
  );
  server.on("connection", (socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
  });
  const sockets_ = new WebSocketServer({
    server,
    path: "/ws",
    handleProtocols: (protocols) => [...protocols][0] ?? false,
  });
  sockets_.on("connection", (socket) => {
    socket.on("message", (data, isBinary) => {
      if (!isBinary && data.toString() === "close") socket.close(4000, "bye");
      else socket.send(data, { binary: isBinary });
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address() as AddressInfo;
  return {
    http: `http://127.0.0.1:${String(port)}`,
    ws: `ws://127.0.0.1:${String(port)}`,
    close: async () => {
      for (const client of sockets_.clients) client.terminate();
      for (const socket of sockets) socket.destroy();
      await new Promise<void>((resolve) =>
        sockets_.close(() => server.close(() => resolve())),
      );
    },
  };
}
