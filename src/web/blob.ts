import type { ReadableStream } from "./streams.ts";
import { bytesOf, encodeUTF8, TextDecoderShim } from "./encoding.ts";
import { byteStream } from "./streams.ts";

const contents = new WeakMap<BlobShim, Uint8Array<ArrayBuffer>>();

export type BlobPart = BlobShim | Blob | ArrayBuffer | ArrayBufferView | string;

function normalizeType(type = ""): string {
  return /^[\x20-\x7E]*$/.test(type) ? type.toLowerCase() : "";
}

export function blobBytes(blob: BlobShim): Uint8Array<ArrayBuffer> {
  const bytes = contents.get(blob);
  if (bytes == null) throw new TypeError("Illegal invocation");
  return bytes;
}

export class BlobShim {
  readonly type: string;

  constructor(parts: Iterable<BlobPart> = [], options: BlobPropertyBag = {}) {
    const source: unknown = parts;
    if (
      typeof source !== "object" ||
      source == null ||
      typeof Reflect.get(source, Symbol.iterator) !== "function"
    ) {
      throw new TypeError("The blob parts must be an iterable");
    }
    const chunks: Array<Uint8Array> = [];
    let length = 0;
    for (const part of parts) {
      let chunk: Uint8Array;
      if (part instanceof BlobShim) chunk = blobBytes(part);
      else if (part instanceof ArrayBuffer || ArrayBuffer.isView(part))
        chunk = new Uint8Array(bytesOf(part));
      else if (typeof part === "string") chunk = encodeUTF8(part);
      else chunk = encodeUTF8(String(part));
      chunks.push(chunk);
      length += chunk.length;
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    contents.set(this, bytes);
    this.type = normalizeType(options.type);
  }

  get size(): number {
    return blobBytes(this).length;
  }

  slice(start?: number, end?: number, contentType?: string): BlobShim {
    const bytes = blobBytes(this);
    const blob = new BlobShim([], { type: contentType });
    contents.set(blob, bytes.slice(start, end));
    return blob;
  }

  async text(): Promise<string> {
    return new TextDecoderShim().decode(blobBytes(this));
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
    return new Uint8Array(blobBytes(this)).buffer;
  }

  async bytes(): Promise<Uint8Array<ArrayBuffer>> {
    return new Uint8Array(blobBytes(this));
  }

  stream(): ReadableStream<Uint8Array<ArrayBuffer>> {
    const bytes = blobBytes(this);
    let offset = 0;
    return byteStream((controller) => {
      if (offset >= bytes.length) {
        controller.close();
        return;
      }
      controller.enqueue(bytes.slice(offset, offset + 65_536));
      offset += 65_536;
    });
  }

  get [Symbol.toStringTag](): string {
    return "Blob";
  }
}

export class FileShim extends BlobShim {
  readonly name: string;
  readonly lastModified: number;
  readonly webkitRelativePath = "";

  constructor(
    parts: Iterable<BlobPart>,
    name: string,
    options: FilePropertyBag = {},
  ) {
    super(parts, options);
    this.name = name;
    this.lastModified = options.lastModified ?? Date.now();
  }

  get [Symbol.toStringTag](): string {
    return "File";
  }
}
