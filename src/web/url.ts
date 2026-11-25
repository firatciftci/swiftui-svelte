import { encodeUTF8, TextDecoderShim } from "./encoding.ts";
import { isIterable } from "./iterable.ts";

const specialPorts = new Map<string, number | null>([
  ["ftp", 21],
  ["file", null],
  ["http", 80],
  ["https", 443],
  ["ws", 80],
  ["wss", 443],
]);

function encodeSet(extra: string, base?: Uint8Array): Uint8Array {
  const set = new Uint8Array(128);
  if (base != null) set.set(base);
  for (let code = 0; code < 0x20; code++) set[code] = 1;
  set[0x7f] = 1;
  for (const character of extra) set[character.charCodeAt(0)] = 1;
  return set;
}

const c0Set = encodeSet("");
const fragmentSet = encodeSet(' "<>`');
const querySet = encodeSet(' "#<>');
const specialQuerySet = encodeSet("'", querySet);
const pathSet = encodeSet("?^`{}", querySet);
const userinfoSet = encodeSet(String.raw`/:;=@[\]|`, pathSet);
const componentSet = encodeSet("$%&+,", userinfoSet);
const formSet = encodeSet("!'()~", componentSet);

const hex = "0123456789ABCDEF";

function encodeByte(byte: number): string {
  return `%${hex.charAt(byte >> 4)}${hex.charAt(byte & 15)}`;
}

function percentEncode(
  text: string,
  set: Uint8Array,
  isSpaceAsPlus = false,
): string {
  let output = "";
  for (const character of text) {
    const code = character.codePointAt(0) ?? 0;
    if (isSpaceAsPlus && code === 0x20) output += "+";
    else if (code < 0x80 && set[code] !== 1) output += character;
    else if (code < 0x80) output += encodeByte(code);
    else for (const byte of encodeUTF8(character)) output += encodeByte(byte);
  }
  return output;
}

function hexValue(code: number): number {
  if (code >= 0x30 && code <= 0x39) return code - 0x30;
  if (code >= 0x41 && code <= 0x46) return code - 0x37;
  if (code >= 0x61 && code <= 0x66) return code - 0x57;
  return -1;
}

function percentDecode(input: Uint8Array): Uint8Array {
  const output = new Uint8Array(input.length);
  let written = 0;
  for (let index = 0; index < input.length; index++) {
    const byte = input[index] ?? 0;
    if (byte === 0x25 && index + 2 < input.length) {
      const high = hexValue(input[index + 1] ?? 0);
      const low = hexValue(input[index + 2] ?? 0);
      if (high >= 0 && low >= 0) {
        output[written++] = (high << 4) | low;
        index += 2;
        continue;
      }
    }
    output[written++] = byte;
  }
  return output.subarray(0, written);
}

const decoder = new TextDecoderShim("utf-8", { ignoreBOM: true });

function decodeComponent(text: string): string {
  return decoder.decode(percentDecode(encodeUTF8(text)));
}

const punycodeBase = 36;

function adapt(delta: number, points: number, isFirst: boolean): number {
  let scaled = isFirst ? Math.floor(delta / 700) : delta >> 1;
  scaled += Math.floor(scaled / points);
  let k = 0;
  while (scaled > 455) {
    scaled = Math.floor(scaled / 35);
    k += punycodeBase;
  }
  return k + Math.floor((36 * scaled) / (scaled + 38));
}

function digit(value: number): string {
  return String.fromCharCode(value + 22 + 75 * (value < 26 ? 1 : 0));
}

function punycode(label: string): string {
  const codes = Array.from(label, (character) => character.codePointAt(0) ?? 0);
  let output = "";
  for (const code of codes)
    if (code < 0x80) output += String.fromCharCode(code);
  const basic = output.length;
  let handled = basic;
  if (basic > 0) output += "-";
  let n = 0x80;
  let delta = 0;
  let bias = 72;
  while (handled < codes.length) {
    let next = Number.MAX_SAFE_INTEGER;
    for (const code of codes) if (code >= n && code < next) next = code;
    delta += (next - n) * (handled + 1);
    n = next;
    for (const code of codes) {
      if (code < n) delta++;
      if (code !== n) continue;
      let q = delta;
      for (let k = punycodeBase; ; k += punycodeBase) {
        const t = k <= bias ? 1 : k >= bias + 26 ? 26 : k - bias;
        if (q < t) break;
        output += digit(t + ((q - t) % (punycodeBase - t)));
        q = Math.floor((q - t) / (punycodeBase - t));
      }
      output += digit(q);
      bias = adapt(delta, handled + 1, handled === basic);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return output;
}

const forbiddenHost = /[\0\t\n\r #/:<>?@[\\\]^|]/;
const forbiddenDomain = /[\0-\x1F #%/:<>?@[\\\]^|\x7F]/;

function domainToASCII(domain: string): string | null {
  const mapped = domain
    .normalize("NFKC")
    .toLowerCase()
    .normalize("NFKC")
    .replaceAll(/[\u3002\uFF0E\uFF61]/g, ".")
    .replaceAll(/[\u00AD\u200B\u2060\uFEFF]/g, "")
    .replaceAll(/[\u034F\u180B-\u180D\uFE00-\uFE0F]/g, "");
  if (
    /[\uFFFD\uFDD0-\uFDEF\uFFFE\uFFFF\uD800-\uDFFF\uE000-\uF8FF]/.test(mapped)
  )
    return null;
  const labels = mapped
    .split(".")
    .map((label) =>
      /^[\x00-\x7F]*$/.test(label) ? label : `xn--${punycode(label)}`,
    );
  const result = labels.join(".");
  if (result === "") return null;
  return result;
}

function parseIPv4Number(text: string): number | null {
  if (text === "") return null;
  let input = text;
  let radix = 10;
  if (input.length >= 2 && (input.startsWith("0x") || input.startsWith("0X"))) {
    input = input.slice(2);
    radix = 16;
  } else if (input.length >= 2 && input.startsWith("0")) {
    input = input.slice(1);
    radix = 8;
  }
  if (input === "") return 0;
  const pattern =
    radix === 10 ? /^\d+$/ : radix === 16 ? /^[0-9a-f]+$/i : /^[0-7]+$/;
  if (!pattern.test(input)) return null;
  return Number.parseInt(input, radix);
}

function isEndingInNumber(text: string): boolean {
  const parts = text.split(".");
  if (parts.at(-1) === "") {
    if (parts.length === 1) return false;
    parts.pop();
  }
  const last = parts.at(-1) ?? "";
  if (last !== "" && /^\d+$/.test(last)) return true;
  return parseIPv4Number(last) != null;
}

function parseIPv4(text: string): string | null {
  const parts = text.split(".");
  if (parts.at(-1) === "" && parts.length > 1) parts.pop();
  if (parts.length > 4) return null;
  const numbers: Array<number> = [];
  for (const part of parts) {
    const value = parseIPv4Number(part);
    if (value == null) return null;
    numbers.push(value);
  }
  const last = numbers.pop() ?? 0;
  if (numbers.some((value) => value > 255) || last >= 256 ** (5 - parts.length))
    return null;
  let address = last;
  for (const [index, value] of numbers.entries())
    address += value * 256 ** (3 - index);
  const octets: Array<number> = [];
  for (let index = 0; index < 4; index++) {
    octets.unshift(address % 256);
    address = Math.floor(address / 256);
  }
  return octets.join(".");
}

function isDigit(code: number): boolean {
  return code >= 0x30 && code <= 0x39;
}

function parseIPv6(input: string): string | null {
  const address = [0, 0, 0, 0, 0, 0, 0, 0];
  let pieceIndex = 0;
  let compress: number | null = null;
  let pointer = 0;
  const at = (index: number): number =>
    index < input.length ? input.charCodeAt(index) : -1;
  if (at(pointer) === 0x3a) {
    if (at(pointer + 1) !== 0x3a) return null;
    pointer += 2;
    pieceIndex++;
    compress = pieceIndex;
  }
  while (at(pointer) !== -1) {
    if (pieceIndex === 8) return null;
    if (at(pointer) === 0x3a) {
      if (compress != null) return null;
      pointer++;
      pieceIndex++;
      compress = pieceIndex;
      continue;
    }
    let value = 0;
    let length = 0;
    while (length < 4 && hexValue(at(pointer)) >= 0) {
      value = value * 16 + hexValue(at(pointer));
      pointer++;
      length++;
    }
    if (at(pointer) === 0x2e) {
      if (length === 0) return null;
      pointer -= length;
      if (pieceIndex > 6) return null;
      let numbersSeen = 0;
      while (at(pointer) !== -1) {
        if (numbersSeen > 0) {
          if (at(pointer) === 0x2e && numbersSeen < 4) pointer++;
          else return null;
        }
        if (!isDigit(at(pointer))) return null;
        let ipv4Piece: number | null = null;
        while (isDigit(at(pointer))) {
          const number = at(pointer) - 0x30;
          if (ipv4Piece == null) ipv4Piece = number;
          else if (ipv4Piece === 0) return null;
          else ipv4Piece = ipv4Piece * 10 + number;
          if (ipv4Piece > 255) return null;
          pointer++;
        }
        address[pieceIndex] =
          (address[pieceIndex] ?? 0) * 0x1_00 + (ipv4Piece ?? 0);
        numbersSeen++;
        if (numbersSeen === 2 || numbersSeen === 4) pieceIndex++;
      }
      if (numbersSeen !== 4) return null;
      break;
    }
    if (at(pointer) === 0x3a) {
      pointer++;
      if (at(pointer) === -1) return null;
    } else if (at(pointer) !== -1) {
      return null;
    }
    address[pieceIndex] = value;
    pieceIndex++;
  }
  if (compress != null) {
    let swaps = pieceIndex - compress;
    pieceIndex = 7;
    while (pieceIndex !== 0 && swaps > 0) {
      const swapIndex = compress + swaps - 1;
      const piece = address[pieceIndex] ?? 0;
      address[pieceIndex] = address[swapIndex] ?? 0;
      address[swapIndex] = piece;
      pieceIndex--;
      swaps--;
    }
  } else if (pieceIndex !== 8) {
    return null;
  }
  let bestStart = -1;
  let bestLength = 1;
  for (let index = 0; index < 8;) {
    if (address[index] !== 0) {
      index++;
      continue;
    }
    let end = index;
    while (end < 8 && address[end] === 0) end++;
    if (end - index > bestLength) {
      bestStart = index;
      bestLength = end - index;
    }
    index = end;
  }
  let output = "";
  let isIgnore0 = false;
  for (let index = 0; index < 8; index++) {
    if (isIgnore0 && address[index] === 0) continue;
    isIgnore0 = false;
    if (index === bestStart) {
      output += index === 0 ? "::" : ":";
      isIgnore0 = true;
      continue;
    }
    output += (address[index] ?? 0).toString(16);
    if (index !== 7) output += ":";
  }
  return `[${output}]`;
}

function parseHost(input: string, isOpaque: boolean): string | null {
  if (input.startsWith("[")) {
    if (!input.endsWith("]")) return null;
    return parseIPv6(input.slice(1, -1));
  }
  if (isOpaque) {
    if (forbiddenHost.test(input)) return null;
    return percentEncode(input, c0Set);
  }
  const domain = decodeComponent(input);
  const ascii = domainToASCII(domain);
  if (ascii == null || forbiddenDomain.test(ascii)) return null;
  if (isEndingInNumber(ascii)) return parseIPv4(ascii);
  return ascii;
}

type URLRecord = {
  scheme: string;
  username: string;
  password: string;
  host: string | null;
  port: number | null;
  path: Array<string> | string;
  query: string | null;
  fragment: string | null;
};

const State = {
  SchemeStart: 0,
  Scheme: 1,
  NoScheme: 2,
  SpecialRelativeOrAuthority: 3,
  PathOrAuthority: 4,
  Relative: 5,
  RelativeSlash: 6,
  SpecialAuthoritySlashes: 7,
  SpecialAuthorityIgnoreSlashes: 8,
  Authority: 9,
  Host: 10,
  Hostname: 11,
  Port: 12,
  File: 13,
  FileSlash: 14,
  FileHost: 15,
  PathStart: 16,
  Path: 17,
  OpaquePath: 18,
  Query: 19,
  Fragment: 20,
} as const;

type ParseState = (typeof State)[keyof typeof State];

const driveLetter = /^[A-Z][:|]$/i;
const normalizedDriveLetter = /^[A-Z]:$/i;
const isStartingWithDriveLetter = (
  points: Array<string>,
  start: number,
): boolean =>
  points.length - start >= 2 &&
  driveLetter.test((points[start] ?? "") + (points[start + 1] ?? "")) &&
  (points.length - start === 2 ||
    String.raw`/\?#`.includes(points[start + 2] ?? ""));
const isSingleDot = (text: string): boolean =>
  text === "." || text.toLowerCase() === "%2e";
const isDoubleDot = (text: string): boolean =>
  ["..", ".%2e", "%2e.", "%2e%2e"].includes(text.toLowerCase());

function isSpecial(url: URLRecord): boolean {
  return specialPorts.has(url.scheme);
}

function shortenPath(url: URLRecord): void {
  if (typeof url.path === "string") return;
  if (
    url.scheme === "file" &&
    url.path.length === 1 &&
    normalizedDriveLetter.test(url.path[0] ?? "")
  )
    return;
  url.path.pop();
}

function stripTrailingSpaces(url: URLRecord): void {
  if (typeof url.path !== "string" || url.fragment != null || url.query != null)
    return;
  url.path = url.path.replace(/ +$/, "");
}

function emptyRecord(): URLRecord {
  return {
    scheme: "",
    username: "",
    password: "",
    host: null,
    port: null,
    path: [],
    query: null,
    fragment: null,
  };
}

const failure = Symbol("failure");

function basicParse(
  rawInput: string,
  base: URLRecord | null,
  existing?: URLRecord,
  override?: ParseState,
): URLRecord | typeof failure | undefined {
  let input = rawInput;
  const url = existing ?? emptyRecord();
  if (existing == null)
    input = input.replaceAll(/^[\0-\x20]+|[\0-\x20]+$/g, "");
  input = input.replaceAll(/[\t\n\r]/g, "");
  const points = [...input];
  let state = override ?? State.SchemeStart;
  let buffer = "";
  let isAtSignSeen = false;
  let isInsideBrackets = false;
  let isPasswordTokenSeen = false;
  let pointer = 0;
  const isNextSlash = (): boolean => points[pointer + 1] === "/";

  for (; pointer <= points.length; pointer++) {
    const c = points[pointer];
    switch (state) {
      case State.SchemeStart: {
        if (c != null && /^[A-Z]$/i.test(c)) {
          buffer += c.toLowerCase();
          state = State.Scheme;
        } else if (override == null) {
          state = State.NoScheme;
          pointer--;
        } else {
          return failure;
        }
        break;
      }
      case State.Scheme: {
        if (c != null && /^[A-Z0-9+\-.]$/i.test(c)) {
          buffer += c.toLowerCase();
        } else if (c === ":") {
          if (override != null) {
            if (specialPorts.has(url.scheme) !== specialPorts.has(buffer))
              return undefined;
            if (
              buffer === "file" &&
              (url.username !== "" || url.password !== "" || url.port != null)
            ) {
              return undefined;
            }
            if (url.scheme === "file" && url.host === "") return undefined;
          }
          url.scheme = buffer;
          if (override != null) {
            if (url.port === specialPorts.get(url.scheme)) url.port = null;
            return undefined;
          }
          buffer = "";
          if (url.scheme === "file") {
            state = State.File;
          } else if (base?.scheme === url.scheme && isSpecial(url)) {
            state = State.SpecialRelativeOrAuthority;
          } else if (isSpecial(url)) {
            state = State.SpecialAuthoritySlashes;
          } else if (isNextSlash()) {
            state = State.PathOrAuthority;
            pointer++;
          } else {
            url.path = "";
            state = State.OpaquePath;
          }
        } else if (override == null) {
          buffer = "";
          state = State.NoScheme;
          pointer = -1;
        } else {
          return failure;
        }
        break;
      }
      case State.NoScheme: {
        if (base == null || (c !== "#" && typeof base.path === "string")) {
          return failure;
        }
        if (c === "#" && typeof base.path === "string") {
          url.scheme = base.scheme;
          url.path = base.path;
          url.query = base.query;
          url.fragment = "";
          state = State.Fragment;
        } else if (base.scheme !== "file") {
          state = State.Relative;
          pointer--;
        } else {
          state = State.File;
          pointer--;
        }
        break;
      }
      case State.SpecialRelativeOrAuthority: {
        if (c === "/" && isNextSlash()) {
          state = State.SpecialAuthorityIgnoreSlashes;
          pointer++;
        } else {
          state = State.Relative;
          pointer--;
        }
        break;
      }
      case State.PathOrAuthority: {
        if (c === "/") {
          state = State.Authority;
        } else {
          state = State.Path;
          pointer--;
        }
        break;
      }
      case State.Relative: {
        if (base == null) return failure;
        url.scheme = base.scheme;
        if (c === "/" || (c === "\\" && isSpecial(url))) {
          state = State.RelativeSlash;
        } else {
          url.username = base.username;
          url.password = base.password;
          url.host = base.host;
          url.port = base.port;
          url.path = typeof base.path === "string" ? base.path : [...base.path];
          url.query = base.query;
          if (c === "?") {
            url.query = "";
            state = State.Query;
          } else if (c === "#") {
            url.fragment = "";
            state = State.Fragment;
          } else if (c != null) {
            url.query = null;
            shortenPath(url);
            state = State.Path;
            pointer--;
          }
        }
        break;
      }
      case State.RelativeSlash: {
        if (isSpecial(url) && (c === "/" || c === "\\")) {
          state = State.SpecialAuthorityIgnoreSlashes;
        } else if (c === "/") {
          state = State.Authority;
        } else {
          if (base != null) {
            url.username = base.username;
            url.password = base.password;
            url.host = base.host;
            url.port = base.port;
          }
          state = State.Path;
          pointer--;
        }
        break;
      }
      case State.SpecialAuthoritySlashes: {
        state = State.SpecialAuthorityIgnoreSlashes;
        if (c === "/" && isNextSlash()) pointer++;
        else pointer--;
        break;
      }
      case State.SpecialAuthorityIgnoreSlashes: {
        if (c !== "/" && c !== "\\") {
          state = State.Authority;
          pointer--;
        }
        break;
      }
      case State.Authority: {
        if (c === "@") {
          if (isAtSignSeen) buffer = `%40${buffer}`;
          isAtSignSeen = true;
          for (const point of buffer) {
            if (point === ":" && !isPasswordTokenSeen) {
              isPasswordTokenSeen = true;
              continue;
            }
            const encoded = percentEncode(point, userinfoSet);
            if (isPasswordTokenSeen) url.password += encoded;
            else url.username += encoded;
          }
          buffer = "";
        } else if (
          c == null ||
          c === "/" ||
          c === "?" ||
          c === "#" ||
          (c === "\\" && isSpecial(url))
        ) {
          if (isAtSignSeen && buffer === "") return failure;
          pointer -= [...buffer].length + 1;
          buffer = "";
          state = State.Host;
        } else {
          buffer += c;
        }
        break;
      }
      case State.Host:
      case State.Hostname: {
        if (override != null && url.scheme === "file") {
          pointer--;
          state = State.FileHost;
        } else if (c === ":" && !isInsideBrackets) {
          if (buffer === "" || override === State.Hostname) return failure;
          const host = parseHost(buffer, !isSpecial(url));
          if (host == null) return failure;
          url.host = host;
          buffer = "";
          state = State.Port;
        } else if (
          c == null ||
          c === "/" ||
          c === "?" ||
          c === "#" ||
          (c === "\\" && isSpecial(url))
        ) {
          pointer--;
          if (buffer === "" && isSpecial(url)) return failure;
          if (
            override != null &&
            buffer === "" &&
            (url.username !== "" || url.password !== "" || url.port != null)
          ) {
            return failure;
          }
          const host = parseHost(buffer, !isSpecial(url));
          if (host == null) return failure;
          url.host = host;
          buffer = "";
          state = State.PathStart;
          if (override != null) return undefined;
        } else {
          if (c === "[") isInsideBrackets = true;
          else if (c === "]") isInsideBrackets = false;
          buffer += c;
        }
        break;
      }
      case State.Port: {
        if (c != null && /^\d$/.test(c)) {
          buffer += c;
        } else if (
          override != null ||
          c == null ||
          c === "/" ||
          c === "?" ||
          c === "#" ||
          (c === "\\" && isSpecial(url))
        ) {
          if (buffer !== "") {
            const port = Number(buffer);
            if (port > 65_535) return failure;
            url.port = port === specialPorts.get(url.scheme) ? null : port;
            buffer = "";
            if (override != null) return undefined;
          }
          if (override != null) return failure;
          state = State.PathStart;
          pointer--;
        } else {
          return failure;
        }
        break;
      }
      case State.File: {
        url.scheme = "file";
        url.host = "";
        if (c === "/" || c === "\\") {
          state = State.FileSlash;
        } else if (base?.scheme === "file") {
          url.host = base.host;
          url.path = typeof base.path === "string" ? base.path : [...base.path];
          url.query = base.query;
          if (c === "?") {
            url.query = "";
            state = State.Query;
          } else if (c === "#") {
            url.fragment = "";
            state = State.Fragment;
          } else if (c != null) {
            url.query = null;
            if (isStartingWithDriveLetter(points, pointer)) url.path = [];
            else shortenPath(url);
            state = State.Path;
            pointer--;
          }
        } else {
          state = State.Path;
          pointer--;
        }
        break;
      }
      case State.FileSlash: {
        if (c === "/" || c === "\\") {
          state = State.FileHost;
        } else {
          if (base?.scheme === "file") {
            url.host = base.host;
            const first =
              typeof base.path === "string" ? undefined : base.path[0];
            if (
              first != null &&
              typeof url.path !== "string" &&
              !isStartingWithDriveLetter(points, pointer) &&
              normalizedDriveLetter.test(first)
            ) {
              url.path.push(first);
            }
          }
          state = State.Path;
          pointer--;
        }
        break;
      }
      case State.FileHost: {
        if (c == null || c === "/" || c === "\\" || c === "?" || c === "#") {
          pointer--;
          if (override == null && driveLetter.test(buffer)) {
            state = State.Path;
          } else if (buffer === "") {
            url.host = "";
            if (override != null) return undefined;
            state = State.PathStart;
          } else {
            let host = parseHost(buffer, !isSpecial(url));
            if (host == null) return failure;
            if (host === "localhost") host = "";
            url.host = host;
            if (override != null) return undefined;
            buffer = "";
            state = State.PathStart;
          }
        } else {
          buffer += c;
        }
        break;
      }
      case State.PathStart: {
        if (isSpecial(url)) {
          state = State.Path;
          if (c !== "/" && c !== "\\") pointer--;
        } else if (override == null && c === "?") {
          url.query = "";
          state = State.Query;
        } else if (override == null && c === "#") {
          url.fragment = "";
          state = State.Fragment;
        } else if (c != null) {
          state = State.Path;
          if (c !== "/") pointer--;
        } else if (
          override != null &&
          url.host == null &&
          typeof url.path !== "string"
        ) {
          url.path.push("");
        }
        break;
      }
      case State.Path: {
        const path = typeof url.path === "string" ? [] : url.path;
        const isSlash = c === "/" || (c === "\\" && isSpecial(url));
        if (
          c == null ||
          isSlash ||
          (override == null && (c === "?" || c === "#"))
        ) {
          if (isDoubleDot(buffer)) {
            shortenPath(url);
            if (!isSlash) path.push("");
          } else if (!isSlash && isSingleDot(buffer)) {
            path.push("");
          } else if (!isSingleDot(buffer)) {
            if (
              url.scheme === "file" &&
              path.length === 0 &&
              driveLetter.test(buffer)
            ) {
              buffer = `${buffer.charAt(0)}:`;
            }
            path.push(buffer);
          }
          url.path = path;
          buffer = "";
          if (c === "?") {
            url.query = "";
            state = State.Query;
          } else if (c === "#") {
            url.fragment = "";
            state = State.Fragment;
          }
        } else {
          buffer += percentEncode(c, pathSet);
        }
        break;
      }
      case State.OpaquePath: {
        if (c === "?") {
          url.query = "";
          state = State.Query;
        } else if (c === "#") {
          url.fragment = "";
          state = State.Fragment;
        } else if (
          c === " " &&
          (points[pointer + 1] === "?" || points[pointer + 1] === "#")
        ) {
          url.path = `${serializePath(url)}%20`;
        } else if (c != null) {
          url.path = serializePath(url) + percentEncode(c, c0Set);
        }
        break;
      }
      case State.Query: {
        if (c == null || (override == null && c === "#")) {
          url.query =
            (url.query ?? "") +
            percentEncode(buffer, isSpecial(url) ? specialQuerySet : querySet);
          buffer = "";
          if (c === "#") {
            url.fragment = "";
            state = State.Fragment;
          }
        } else {
          buffer += c;
        }
        break;
      }
      case State.Fragment: {
        if (c != null)
          url.fragment = (url.fragment ?? "") + percentEncode(c, fragmentSet);
        break;
      }
    }
  }
  return url;
}

export function compareCodeUnits(left: string, right: string): number {
  if (left < right) return -1;
  return left > right ? 1 : 0;
}

function serializePath(url: URLRecord): string {
  if (typeof url.path === "string") return url.path;
  let output = "";
  for (const segment of url.path) output += `/${segment}`;
  return output;
}

function serialize(url: URLRecord): string {
  let output = `${url.scheme}:`;
  if (url.host != null) {
    output += "//";
    if (url.username !== "" || url.password !== "") {
      output += url.username;
      if (url.password !== "") output += `:${url.password}`;
      output += "@";
    }
    output += url.host;
    if (url.port != null) output += `:${String(url.port)}`;
  } else if (
    typeof url.path !== "string" &&
    url.path.length > 1 &&
    url.path[0] === ""
  ) {
    output += "/.";
  }
  output += serializePath(url);
  if (url.query != null) output += `?${url.query}`;
  if (url.fragment != null) output += `#${url.fragment}`;
  return output;
}

function canHaveCredentials(url: URLRecord): boolean {
  return url.host != null && url.host !== "" && url.scheme !== "file";
}

const records = new WeakMap<URLShim, URLRecord>();
const queries = new WeakMap<URLShim, URLSearchParamsShim>();
const owners = new WeakMap<URLSearchParamsShim, URLShim>();
const lists = new WeakMap<URLSearchParamsShim, Array<[string, string]>>();

function record(url: URLShim): URLRecord {
  const value = records.get(url);
  if (value == null) throw new TypeError("Illegal invocation");
  return value;
}

function parseRecord(
  input: string,
  base?: string | URLShim | URL,
): URLRecord | null {
  let baseRecord: URLRecord | null = null;
  if (base !== undefined) {
    const parsedBase = basicParse(String(base), null);
    if (parsedBase === failure || parsedBase == null) return null;
    baseRecord = parsedBase;
  }
  const parsed = basicParse(input, baseRecord);
  return parsed === failure || parsed == null ? null : parsed;
}

function parseForm(input: string): Array<[string, string]> {
  const list: Array<[string, string]> = [];
  for (const sequence of input.split("&")) {
    if (sequence === "") continue;
    const equals = sequence.indexOf("=");
    const name = equals === -1 ? sequence : sequence.slice(0, equals);
    const value = equals === -1 ? "" : sequence.slice(equals + 1);
    list.push([
      decodeComponent(name.replaceAll("+", " ")),
      decodeComponent(value.replaceAll("+", " ")),
    ]);
  }
  return list;
}

function serializeForm(list: Array<[string, string]>): string {
  return list
    .map(
      ([name, value]) =>
        `${percentEncode(name, formSet, true)}=${percentEncode(value, formSet, true)}`,
    )
    .join("&");
}

function toUSVString(value: unknown): string {
  return String(value).toWellFormed();
}

export class URLShim {
  static canParse(
    url: string | URLShim | URL,
    base?: string | URLShim | URL,
  ): boolean {
    return (
      parseRecord(
        toUSVString(url),
        base === undefined ? undefined : toUSVString(base),
      ) != null
    );
  }

  static parse(
    url: string | URLShim | URL,
    base?: string | URLShim | URL,
  ): URLShim | null {
    try {
      return new URLShim(url, base);
    } catch {
      return null;
    }
  }

  constructor(url: string | URLShim | URL, base?: string | URLShim | URL) {
    const parsed = parseRecord(
      toUSVString(url),
      base === undefined ? undefined : toUSVString(base),
    );
    if (parsed == null) throw new TypeError(`Invalid URL: ${String(url)}`);
    records.set(this, parsed);
    const params = new URLSearchParamsShim();
    lists.set(params, parseForm(parsed.query ?? ""));
    owners.set(params, this);
    queries.set(this, params);
  }

  get href(): string {
    return serialize(record(this));
  }

  set href(value: string) {
    const parsed = parseRecord(toUSVString(value));
    if (parsed == null) throw new TypeError(`Invalid URL: ${value}`);
    records.set(this, parsed);
    const params = queries.get(this);
    if (params != null) lists.set(params, parseForm(parsed.query ?? ""));
  }

  get origin(): string {
    const url = record(this);
    if (url.scheme === "blob") {
      const inner = parseRecord(serializePath(url));
      if (
        inner != null &&
        (inner.scheme === "http" || inner.scheme === "https")
      )
        return new URLShim(serialize(inner)).origin;
      return "null";
    }
    if (url.scheme === "file" || !isSpecial(url)) return "null";
    return `${url.scheme}://${url.host ?? ""}${url.port == null ? "" : `:${String(url.port)}`}`;
  }

  get protocol(): string {
    return `${record(this).scheme}:`;
  }

  set protocol(value: string) {
    basicParse(`${toUSVString(value)}:`, null, record(this), State.SchemeStart);
  }

  get username(): string {
    return record(this).username;
  }

  set username(value: string) {
    const url = record(this);
    if (!canHaveCredentials(url)) return;
    url.username = percentEncode(toUSVString(value), userinfoSet);
  }

  get password(): string {
    return record(this).password;
  }

  set password(value: string) {
    const url = record(this);
    if (!canHaveCredentials(url)) return;
    url.password = percentEncode(toUSVString(value), userinfoSet);
  }

  get host(): string {
    const url = record(this);
    if (url.host == null) return "";
    return url.port == null ? url.host : `${url.host}:${String(url.port)}`;
  }

  set host(value: string) {
    const url = record(this);
    if (typeof url.path === "string") return;
    basicParse(toUSVString(value), null, url, State.Host);
  }

  get hostname(): string {
    return record(this).host ?? "";
  }

  set hostname(value: string) {
    const url = record(this);
    if (typeof url.path === "string") return;
    basicParse(toUSVString(value), null, url, State.Hostname);
  }

  get port(): string {
    const { port } = record(this);
    return port == null ? "" : String(port);
  }

  set port(value: string) {
    const url = record(this);
    if (!canHaveCredentials(url)) return;
    const text = toUSVString(value);
    if (text === "") url.port = null;
    else basicParse(text, null, url, State.Port);
  }

  get pathname(): string {
    return serializePath(record(this));
  }

  set pathname(value: string) {
    const url = record(this);
    if (typeof url.path === "string") return;
    url.path = [];
    basicParse(toUSVString(value), null, url, State.PathStart);
  }

  get search(): string {
    const { query } = record(this);
    return query == null || query === "" ? "" : `?${query}`;
  }

  set search(value: string) {
    const url = record(this);
    const params = queries.get(this);
    const text = toUSVString(value);
    if (text === "") {
      url.query = null;
      if (params != null) lists.set(params, []);
      stripTrailingSpaces(url);
      return;
    }
    url.query = "";
    basicParse(
      text.startsWith("?") ? text.slice(1) : text,
      null,
      url,
      State.Query,
    );
    if (params != null) lists.set(params, parseForm(url.query));
  }

  get searchParams(): URLSearchParamsShim {
    const params = queries.get(this);
    if (params == null) throw new TypeError("Illegal invocation");
    return params;
  }

  get hash(): string {
    const { fragment } = record(this);
    return fragment == null || fragment === "" ? "" : `#${fragment}`;
  }

  set hash(value: string) {
    const url = record(this);
    const text = toUSVString(value);
    if (text === "") {
      url.fragment = null;
      stripTrailingSpaces(url);
      return;
    }
    url.fragment = "";
    basicParse(
      text.startsWith("#") ? text.slice(1) : text,
      null,
      url,
      State.Fragment,
    );
  }

  toString(): string {
    return this.href;
  }

  toJSON(): string {
    return this.href;
  }

  get [Symbol.toStringTag](): string {
    return "URL";
  }
}

function list(params: URLSearchParamsShim): Array<[string, string]> {
  const value = lists.get(params);
  if (value == null) throw new TypeError("Illegal invocation");
  return value;
}

function update(params: URLSearchParamsShim): void {
  const owner = owners.get(params);
  if (owner == null) return;
  const url = record(owner);
  const serialized = serializeForm(list(params));
  url.query = serialized === "" ? null : serialized;
  if (url.query == null) stripTrailingSpaces(url);
}

type SearchParamsInit =
  | string
  | URLSearchParamsShim
  | URLSearchParams
  | Iterable<Iterable<string>>
  | Record<string, string>;

export class URLSearchParamsShim {
  constructor(init: SearchParamsInit = "") {
    const entries: Array<[string, string]> = [];
    const source: unknown = init;
    if (typeof source === "object" && source != null) {
      if (isIterable(source)) {
        for (const pair of source) {
          if (!isIterable(pair))
            throw new TypeError(
              "Each query pair must be an iterable [name, value] tuple",
            );
          const values = [...pair];
          if (values.length !== 2)
            throw new TypeError(
              "Each query pair must be an iterable [name, value] tuple",
            );
          entries.push([toUSVString(values[0]), toUSVString(values[1])]);
        }
      } else {
        for (const [name, value] of Object.entries(source)) {
          entries.push([toUSVString(name), toUSVString(value)]);
        }
      }
    } else {
      const text = toUSVString(init);
      entries.push(...parseForm(text.startsWith("?") ? text.slice(1) : text));
    }
    lists.set(this, entries);
  }

  get size(): number {
    return list(this).length;
  }

  append(name: string, value: string): void {
    list(this).push([toUSVString(name), toUSVString(value)]);
    update(this);
  }

  delete(name: string, value?: string): void {
    const key = toUSVString(name);
    const match = value === undefined ? undefined : toUSVString(value);
    lists.set(
      this,
      list(this).filter(
        ([entryName, entryValue]) =>
          entryName !== key || (match !== undefined && entryValue !== match),
      ),
    );
    update(this);
  }

  get(name: string): string | null {
    const key = toUSVString(name);
    return list(this).find(([entryName]) => entryName === key)?.[1] ?? null;
  }

  getAll(name: string): Array<string> {
    const key = toUSVString(name);
    return list(this)
      .filter(([entryName]) => entryName === key)
      .map(([, value]) => value);
  }

  has(name: string, value?: string): boolean {
    const key = toUSVString(name);
    const match = value === undefined ? undefined : toUSVString(value);
    return list(this).some(
      ([entryName, entryValue]) =>
        entryName === key && (match === undefined || entryValue === match),
    );
  }

  set(name: string, value: string): void {
    const key = toUSVString(name);
    const text = toUSVString(value);
    const entries = list(this);
    const index = entries.findIndex(([entryName]) => entryName === key);
    if (index === -1) {
      entries.push([key, text]);
    } else {
      entries[index] = [key, text];
      lists.set(
        this,
        entries.filter(
          ([entryName], position) => position <= index || entryName !== key,
        ),
      );
    }
    update(this);
  }

  sort(): void {
    lists.set(
      this,
      list(this).toSorted(([left], [right]) => compareCodeUnits(left, right)),
    );
    update(this);
  }

  forEach(
    callback: (
      value: string,
      name: string,
      params: URLSearchParamsShim,
    ) => void,
    thisArg?: unknown,
  ): void {
    for (const [name, value] of list(this))
      callback.call(thisArg, value, name, this);
  }

  *entries(): Generator<[string, string], undefined, unknown> {
    for (let index = 0; index < list(this).length; index++) {
      const entry = list(this)[index];
      if (entry != null) yield [entry[0], entry[1]];
    }
  }

  *keys(): Generator<string, undefined, unknown> {
    for (const [name] of this.entries()) yield name;
  }

  *values(): Generator<string, undefined, unknown> {
    for (const [, value] of this.entries()) yield value;
  }

  [Symbol.iterator](): Generator<[string, string], undefined, unknown> {
    return this.entries();
  }

  toString(): string {
    return serializeForm(list(this));
  }

  get [Symbol.toStringTag](): string {
    return "URLSearchParams";
  }
}

export const formEncoding = { parse: parseForm, serialize: serializeForm };
