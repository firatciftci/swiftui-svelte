import type { WritableStream } from "web-streams-polyfill";
import {
  ReadableStream,
  ReadableStreamBYOBReader,
  ReadableStreamDefaultReader,
  TransformStream,
} from "web-streams-polyfill";
import { encodeUTF8, TextDecoderShim } from "./encoding.ts";

export {
  ByteLengthQueuingStrategy,
  CountQueuingStrategy,
  ReadableByteStreamController,
  ReadableStream,
  ReadableStreamBYOBReader,
  ReadableStreamBYOBRequest,
  ReadableStreamDefaultController,
  ReadableStreamDefaultReader,
  TransformStream,
  TransformStreamDefaultController,
  WritableStream,
  WritableStreamDefaultController,
  WritableStreamDefaultWriter,
} from "web-streams-polyfill";

const disturbed = new WeakSet<object>();
const owners = new WeakMap<object, object>();

function wrap(
  prototype: object,
  name: PropertyKey,
  around: (call: () => unknown, target: object) => unknown,
): void {
  const original: unknown = Reflect.get(prototype, name);
  if (typeof original !== "function") return;
  Object.defineProperty(prototype, name, {
    value(this: object, ...args: Array<unknown>): unknown {
      return around(() => Reflect.apply(original, this, args), this);
    },
    writable: true,
    configurable: true,
  });
}

wrap(ReadableStream.prototype, "getReader", (call, stream) => {
  const reader = call();
  if (typeof reader === "object" && reader != null) owners.set(reader, stream);
  return reader;
});
for (const name of [
  "cancel",
  "pipeTo",
  "pipeThrough",
  "values",
  Symbol.asyncIterator,
]) {
  wrap(ReadableStream.prototype, name, (call, stream) => {
    disturbed.add(stream);
    return call();
  });
}
for (const reader of [ReadableStreamDefaultReader, ReadableStreamBYOBReader]) {
  for (const name of ["read", "cancel"]) {
    wrap(reader.prototype, name, (call, target) => {
      const stream = owners.get(target);
      if (stream != null) disturbed.add(stream);
      return call();
    });
  }
}

export type ByteStream = {
  readonly locked: boolean;
  getReader: () => { read: () => Promise<{ done: boolean; value?: unknown }> };
  tee: () => [ByteStream, ByteStream];
};

export function isReadableStream(value: unknown): value is ByteStream {
  return (
    typeof value === "object" &&
    value != null &&
    typeof Reflect.get(value, "getReader") === "function" &&
    typeof Reflect.get(value, "locked") === "boolean"
  );
}

export function isDisturbed(stream: object): boolean {
  return disturbed.has(stream);
}

export function byteStream(
  pull: (controller: {
    enqueue: (chunk: Uint8Array<ArrayBuffer>) => void;
    close: () => void;
  }) => void,
): ReadableStream<Uint8Array<ArrayBuffer>> {
  return new ReadableStream({ type: "bytes", pull });
}

export async function readAll(
  stream: ByteStream,
): Promise<Uint8Array<ArrayBuffer>> {
  const reader = stream.getReader();
  const chunks: Array<Uint8Array> = [];
  let length = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!(value instanceof Uint8Array))
      throw new TypeError("The stream chunk is not a Uint8Array");
    chunks.push(value);
    length += value.length;
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}

function isBufferSource(value: unknown): value is AllowSharedBufferSource {
  return value instanceof ArrayBuffer || ArrayBuffer.isView(value);
}

export class TextDecoderStreamShim {
  readonly encoding: string;
  readonly fatal: boolean;
  readonly ignoreBOM: boolean;
  readonly readable: ReadableStream<string>;
  readonly writable: WritableStream<AllowSharedBufferSource>;

  constructor(label = "utf-8", options: TextDecoderOptions = {}) {
    const decoder = new TextDecoderShim(label, options);
    this.encoding = decoder.encoding;
    this.fatal = decoder.fatal;
    this.ignoreBOM = decoder.ignoreBOM;
    const transform = new TransformStream<AllowSharedBufferSource, string>({
      transform(chunk, controller) {
        if (!isBufferSource(chunk))
          throw new TypeError("The chunk is not an ArrayBuffer or a view");
        const text = decoder.decode(chunk, { stream: true });
        if (text !== "") controller.enqueue(text);
      },
      flush(controller) {
        const text = decoder.decode();
        if (text !== "") controller.enqueue(text);
      },
    });
    this.readable = transform.readable;
    this.writable = transform.writable;
  }

  get [Symbol.toStringTag](): string {
    return "TextDecoderStream";
  }
}

export class TextEncoderStreamShim {
  readonly encoding = "utf-8";
  readonly readable: ReadableStream<Uint8Array<ArrayBuffer>>;
  readonly writable: WritableStream<string>;

  constructor() {
    let pending = "";
    const transform = new TransformStream<unknown, Uint8Array<ArrayBuffer>>({
      transform(chunk, controller) {
        if (typeof chunk === "symbol")
          throw new TypeError("Cannot convert a Symbol to a string");
        let text = pending + String(chunk);
        pending = "";
        const last = text.charCodeAt(text.length - 1);
        if (last >= 0xd8_00 && last <= 0xdb_ff) {
          pending = text.slice(-1);
          text = text.slice(0, -1);
        }
        if (text !== "") controller.enqueue(encodeUTF8(text));
      },
      flush(controller) {
        if (pending !== "")
          controller.enqueue(new Uint8Array([0xef, 0xbf, 0xbd]));
      },
    });
    this.readable = transform.readable;
    this.writable = transform.writable;
  }

  get [Symbol.toStringTag](): string {
    return "TextEncoderStream";
  }
}
