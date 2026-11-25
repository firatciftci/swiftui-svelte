import { DOMExceptionShim } from "./events.ts";

export function bytesOf(
  input: AllowSharedBufferSource | undefined,
): Uint8Array {
  if (input == null) return new Uint8Array();
  if (ArrayBuffer.isView(input)) {
    return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  }
  return new Uint8Array(input);
}

export function encodeUTF8(text: string): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(text.length * 3);
  return bytes.slice(0, writeUTF8(text, bytes).written);
}

function writeUTF8(
  text: string,
  bytes: Uint8Array,
): { read: number; written: number } {
  let read = 0;
  let written = 0;
  const length = text.length;
  while (read < length) {
    let code = text.charCodeAt(read);
    let units = 1;
    if (code >= 0xd8_00 && code <= 0xdf_ff) {
      const next = text.charCodeAt(read + 1);
      if (code <= 0xdb_ff && next >= 0xdc_00 && next <= 0xdf_ff) {
        code = 0x1_00_00 + ((code - 0xd8_00) << 10) + (next - 0xdc_00);
        units = 2;
      } else {
        code = 0xff_fd;
      }
    }
    const size = code < 0x80 ? 1 : code < 0x8_00 ? 2 : code < 0x1_00_00 ? 3 : 4;
    if (written + size > bytes.length) break;
    switch (size) {
      case 1: {
        bytes[written++] = code;

        break;
      }
      case 2: {
        bytes[written++] = 0xc0 | (code >> 6);
        bytes[written++] = 0x80 | (code & 0x3f);

        break;
      }
      case 3: {
        bytes[written++] = 0xe0 | (code >> 12);
        bytes[written++] = 0x80 | ((code >> 6) & 0x3f);
        bytes[written++] = 0x80 | (code & 0x3f);

        break;
      }
      default: {
        bytes[written++] = 0xf0 | (code >> 18);
        bytes[written++] = 0x80 | ((code >> 12) & 0x3f);
        bytes[written++] = 0x80 | ((code >> 6) & 0x3f);
        bytes[written++] = 0x80 | (code & 0x3f);
      }
    }
    read += units;
  }
  return { read, written };
}

export class TextEncoderShim {
  readonly encoding = "utf-8";

  encode(input = ""): Uint8Array<ArrayBuffer> {
    return encodeUTF8(input);
  }

  encodeInto(
    source: string,
    destination: Uint8Array,
  ): TextEncoderEncodeIntoResult {
    return writeUTF8(source, destination);
  }
}

const labels = new Map<string, "utf-8" | "utf-16le" | "windows-1252">();
for (const label of [
  "unicode-1-1-utf-8",
  "unicode11utf8",
  "unicode20utf8",
  "utf-8",
  "utf8",
  "x-unicode20utf8",
]) {
  labels.set(label, "utf-8");
}
for (const label of [
  "csunicode",
  "iso-10646-ucs-2",
  "ucs-2",
  "unicode",
  "unicodefeff",
  "utf-16",
  "utf-16le",
]) {
  labels.set(label, "utf-16le");
}
for (const label of [
  "ansi_x3.4-1968",
  "ascii",
  "cp1252",
  "cp819",
  "csisolatin1",
  "ibm819",
  "iso-8859-1",
  "iso-ir-100",
  "iso8859-1",
  "iso88591",
  "iso_8859-1",
  "iso_8859-1:1987",
  "l1",
  "latin1",
  "us-ascii",
  "windows-1252",
  "x-cp1252",
]) {
  labels.set(label, "windows-1252");
}

const windows1252 = [
  0x20_ac, 0x81, 0x20_1a, 0x1_92, 0x20_1e, 0x20_26, 0x20_20, 0x20_21, 0x2_c6,
  0x20_30, 0x1_60, 0x20_39, 0x1_52, 0x8d, 0x1_7d, 0x8f, 0x90, 0x20_18, 0x20_19,
  0x20_1c, 0x20_1d, 0x20_22, 0x20_13, 0x20_14, 0x2_dc, 0x21_22, 0x1_61, 0x20_3a,
  0x1_53, 0x9d, 0x1_7e, 0x1_78,
];

export class TextDecoderShim {
  #pending: Array<number> = [];
  #started = false;
  readonly encoding: "utf-8" | "utf-16le" | "windows-1252";
  readonly fatal: boolean;
  readonly ignoreBOM: boolean;

  constructor(label = "utf-8", options: TextDecoderOptions = {}) {
    const encoding = labels.get(label.trim().toLowerCase());
    if (encoding == null)
      throw new RangeError(`The "${label}" encoding is not supported`);
    this.encoding = encoding;
    this.fatal = Boolean(options.fatal);
    this.ignoreBOM = Boolean(options.ignoreBOM);
  }

  #invalid(): string {
    if (this.fatal)
      throw new TypeError(
        `The encoded data was not valid for encoding ${this.encoding}`,
      );
    return "\u{FFFD}";
  }

  #windows1252(bytes: Uint8Array): string {
    let text = "";
    for (const byte of bytes) {
      text += String.fromCharCode(
        byte >= 0x80 && byte < 0xa0 ? (windows1252[byte - 0x80] ?? byte) : byte,
      );
    }
    return text;
  }

  #utf16(bytes: Uint8Array, isStream: boolean): string {
    const units: Array<number> = [];
    let index = 0;
    for (; index + 1 < bytes.length; index += 2) {
      units.push((bytes[index] ?? 0) | ((bytes[index + 1] ?? 0) << 8));
    }
    let tail: Array<number> = index < bytes.length ? [bytes[index] ?? 0] : [];
    const last = units.at(-1);
    if (isStream && last != null && last >= 0xd8_00 && last <= 0xdb_ff) {
      units.pop();
      tail = [last & 0xff, last >> 8, ...tail];
    }
    let text = "";
    for (let position = 0; position < units.length; position++) {
      const unit = units[position] ?? 0;
      if (unit >= 0xd8_00 && unit <= 0xdb_ff) {
        const next = units[position + 1];
        if (next != null && next >= 0xdc_00 && next <= 0xdf_ff) {
          text += String.fromCharCode(unit, next);
          position++;
        } else {
          text += this.#invalid();
        }
      } else if (unit >= 0xdc_00 && unit <= 0xdf_ff) {
        text += this.#invalid();
      } else {
        text += String.fromCharCode(unit);
      }
    }
    if (isStream) this.#pending = tail;
    else if (tail.length > 0) text += this.#invalid();
    return text;
  }

  #utf8(bytes: Uint8Array, isStream: boolean): string {
    const chunks: Array<string> = [];
    let units: Array<number> = [];
    const length = bytes.length;
    let index = 0;
    while (index < length) {
      const byte = bytes[index] ?? 0;
      if (byte < 0x80) {
        units.push(byte);
        index++;
      } else {
        let needed = 0;
        let code = 0;
        let lower = 0x80;
        let upper = 0xbf;
        if (byte >= 0xc2 && byte <= 0xdf) {
          needed = 1;
          code = byte & 0x1f;
        } else if (byte >= 0xe0 && byte <= 0xef) {
          needed = 2;
          code = byte & 0x0f;
          if (byte === 0xe0) lower = 0xa0;
          else if (byte === 0xed) upper = 0x9f;
        } else if (byte >= 0xf0 && byte <= 0xf4) {
          needed = 3;
          code = byte & 0x07;
          if (byte === 0xf0) lower = 0x90;
          else if (byte === 0xf4) upper = 0x8f;
        }
        if (needed === 0) {
          units.push(this.#invalid().charCodeAt(0));
          index++;
        } else {
          let seen = 0;
          let position = index + 1;
          while (seen < needed && position < length) {
            const next = bytes[position] ?? 0;
            if (next < lower || next > upper) break;
            lower = 0x80;
            upper = 0xbf;
            code = (code << 6) | (next & 0x3f);
            seen++;
            position++;
          }
          if (seen === needed) {
            if (code >= 0x1_00_00) {
              code -= 0x1_00_00;
              units.push(0xd8_00 + (code >> 10), 0xdc_00 + (code & 0x3_ff));
            } else {
              units.push(code);
            }
          } else if (position === length && isStream) {
            for (let rest = index; rest < length; rest++)
              this.#pending.push(bytes[rest] ?? 0);
            break;
          } else {
            units.push(this.#invalid().charCodeAt(0));
          }
          index = position;
        }
      }
      if (units.length < 8192) continue;
      chunks.push(String.fromCharCode(...units));
      units = [];
    }
    chunks.push(String.fromCharCode(...units));
    return chunks.join("");
  }

  decode(
    input?: AllowSharedBufferSource,
    options: TextDecodeOptions = {},
  ): string {
    const incoming = bytesOf(input);
    let bytes: Uint8Array = incoming;
    if (this.#pending.length > 0) {
      const joined = new Uint8Array(this.#pending.length + incoming.length);
      joined.set(this.#pending);
      joined.set(incoming, this.#pending.length);
      bytes = joined;
      this.#pending = [];
    }
    const isStream = Boolean(options.stream);
    let text = "";
    if (this.encoding === "utf-8") text = this.#utf8(bytes, isStream);
    else if (this.encoding === "utf-16le") text = this.#utf16(bytes, isStream);
    else text = this.#windows1252(bytes);
    if (!this.#started && text.length > 0) {
      this.#started = true;
      if (
        !this.ignoreBOM &&
        this.encoding !== "windows-1252" &&
        text.charCodeAt(0) === 0xfe_ff
      ) {
        text = text.slice(1);
      }
    }
    if (!isStream) this.#started = false;
    return text;
  }
}

const alphabet =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const lookup = new Map<string, number>();
for (const [index, character] of [...alphabet].entries())
  lookup.set(character, index);

function base64Encode(bytes: ArrayLike<number>): string {
  let output = "";
  let index = 0;
  for (; index + 2 < bytes.length; index += 3) {
    const value =
      ((bytes[index] ?? 0) << 16) |
      ((bytes[index + 1] ?? 0) << 8) |
      (bytes[index + 2] ?? 0);
    output +=
      alphabet.charAt(value >> 18) +
      alphabet.charAt((value >> 12) & 63) +
      alphabet.charAt((value >> 6) & 63) +
      alphabet.charAt(value & 63);
  }
  const rest = bytes.length - index;
  if (rest === 1) {
    const value = (bytes[index] ?? 0) << 16;
    output += `${alphabet.charAt(value >> 18)}${alphabet.charAt((value >> 12) & 63)}==`;
  } else if (rest === 2) {
    const value = ((bytes[index] ?? 0) << 16) | ((bytes[index + 1] ?? 0) << 8);
    output += `${alphabet.charAt(value >> 18)}${alphabet.charAt((value >> 12) & 63)}${alphabet.charAt((value >> 6) & 63)}=`;
  }
  return output;
}

export function base64Decode(input: string): Uint8Array<ArrayBuffer> {
  let data = input.replaceAll(/[\t\n\f\r ]/g, "");
  if (data.length % 4 === 0) data = data.replace(/==?$/, "");
  if (data.length % 4 === 1 || /[^+/0-9A-Z]/i.test(data)) {
    throw new DOMExceptionShim(
      "The string to be decoded is not correctly encoded.",
      "InvalidCharacterError",
    );
  }
  const bytes = new Uint8Array(Math.floor((data.length * 3) / 4));
  let written = 0;
  let buffer = 0;
  let bits = 0;
  for (const character of data) {
    buffer = (buffer << 6) | (lookup.get(character) ?? 0);
    bits += 6;
    if (bits < 8) continue;
    bits -= 8;
    bytes[written++] = (buffer >> bits) & 0xff;
  }
  return bytes;
}

export function btoaShim(data: unknown): string {
  const text = String(data);
  const bytes = new Uint8Array(text.length);
  for (let index = 0; index < text.length; index++) {
    const code = text.charCodeAt(index);
    if (code > 0xff) {
      throw new DOMExceptionShim("Invalid character", "InvalidCharacterError");
    }
    bytes[index] = code;
  }
  return base64Encode(bytes);
}

export function atobShim(data: unknown): string {
  const bytes = base64Decode(String(data));
  let text = "";
  for (let index = 0; index < bytes.length; index += 8192) {
    text += String.fromCharCode(...bytes.subarray(index, index + 8192));
  }
  return text;
}
