import { bytesOf } from "./encoding.ts";
import { DOMExceptionShim } from "./events.ts";

export type NativeCryptoBridge = {
  fill: (bytes: Uint8Array<ArrayBuffer>) => void;
  digest: (algorithm: string, data: Uint8Array<ArrayBuffer>) => Uint8Array;
};

const integerArrays = [
  Int8Array,
  Uint8Array,
  Uint8ClampedArray,
  Int16Array,
  Uint16Array,
  Int32Array,
  Uint32Array,
  BigInt64Array,
  BigUint64Array,
];
const digests = new Map([
  ["SHA-1", "SHA-1"],
  ["SHA-256", "SHA-256"],
  ["SHA-384", "SHA-384"],
  ["SHA-512", "SHA-512"],
]);

type UUID = `${string}-${string}-${string}-${string}-${string}`;

type HostCrypto = {
  getRandomValues: <T extends ArrayBufferView | null>(array: T) => T;
  randomUUID: () => UUID;
  subtle: {
    digest: (
      algorithm: string | { name: string },
      data: AllowSharedBufferSource,
    ) => Promise<ArrayBuffer>;
  };
};

export function createCrypto(native: NativeCryptoBridge): HostCrypto {
  const getRandomValues = <T extends ArrayBufferView | null>(array: T): T => {
    if (
      array == null ||
      integerArrays.every((type) => !(array instanceof type))
    ) {
      throw new DOMExceptionShim(
        "The data argument must be an integer-type TypedArray",
        "TypeMismatchError",
      );
    }
    if (array.byteLength > 65_536) {
      throw new DOMExceptionShim(
        `The ArrayBufferView's byte length (${String(array.byteLength)}) exceeds the number of bytes of entropy available via this API (65536)`,
        "QuotaExceededError",
      );
    }
    native.fill(
      new Uint8Array(
        array.buffer as ArrayBuffer,
        array.byteOffset,
        array.byteLength,
      ),
    );
    return array;
  };

  const randomUUID = (): UUID => {
    const bytes = getRandomValues(new Uint8Array(16));
    bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x40;
    bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
    const hex = Array.from(bytes, (byte) =>
      byte.toString(16).padStart(2, "0"),
    ).join("");
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  };

  const subtle = {
    async digest(
      algorithm: string | { name: string },
      data: AllowSharedBufferSource,
    ): Promise<ArrayBuffer> {
      const name = typeof algorithm === "string" ? algorithm : algorithm.name;
      const normalized = digests.get(name.toUpperCase());
      if (normalized == null)
        throw new DOMExceptionShim(
          "Unrecognized algorithm name",
          "NotSupportedError",
        );
      return new Uint8Array(
        native.digest(normalized, new Uint8Array(bytesOf(data))),
      ).buffer;
    },
  };

  return { getRandomValues, randomUUID, subtle };
}
