class AssertionError extends Error {
  override name = "AssertionError";
}

function describe(value: unknown): string {
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "bigint") return `${String(value)}n`;
  if (value instanceof Uint8Array) return `Uint8Array [${value.join(", ")}]`;
  try {
    const text: unknown = JSON.stringify(value);
    return typeof text === "string" ? text : String(value);
  } catch {
    return String(value);
  }
}

export function equal(actual: unknown, expected: unknown, label = ""): void {
  if (!Object.is(actual, expected)) {
    throw new AssertionError(
      `${label === "" ? "" : `${label}: `}expected ${describe(expected)}, got ${describe(actual)}`,
    );
  }
}

export function ok(
  value: unknown,
  label = "expected a truthy value",
): asserts value {
  if (value === false || value == null || value === 0 || value === "")
    throw new AssertionError(label);
}

function isSame(left: unknown, right: unknown): boolean {
  if (Object.is(left, right)) return true;
  if (
    typeof left !== "object" ||
    typeof right !== "object" ||
    left === null ||
    right === null
  )
    return false;
  if (ArrayBuffer.isView(left) && ArrayBuffer.isView(right)) {
    const a = new Uint8Array(left.buffer, left.byteOffset, left.byteLength);
    const b = new Uint8Array(right.buffer, right.byteOffset, right.byteLength);
    return a.length === b.length && a.every((byte, index) => byte === b[index]);
  }
  if (left instanceof Map && right instanceof Map) {
    return (
      left.size === right.size &&
      [...left].every(
        ([key, value]) => right.has(key) && isSame(value, right.get(key)),
      )
    );
  }
  if (left instanceof Set && right instanceof Set) {
    if (left.size !== right.size) return false;
    for (const value of left) if (!right.has(value)) return false;
    return true;
  }
  if (left instanceof Date && right instanceof Date)
    return left.getTime() === right.getTime();
  if (Array.isArray(left) !== Array.isArray(right)) return false;
  const leftKeys = Object.keys(left);
  const rightKeys = Object.keys(right);
  return (
    leftKeys.length === rightKeys.length &&
    leftKeys.every((key) =>
      isSame(Reflect.get(left, key), Reflect.get(right, key)),
    )
  );
}

export function deep(actual: unknown, expected: unknown, label = ""): void {
  if (!isSame(actual, expected)) {
    throw new AssertionError(
      `${label === "" ? "" : `${label}: `}expected ${describe(expected)}, got ${describe(actual)}`,
    );
  }
}

function check(error: unknown, name: string | undefined): void {
  if (name == null) return;
  const actual =
    error instanceof Error ||
    (typeof error === "object" && error !== null && "name" in error)
      ? String(error.name)
      : typeof error;
  if (actual !== name)
    throw new AssertionError(
      `expected a ${name}, got ${actual}: ${String(error)}`,
    );
}

export function throws(run: () => unknown, name?: string): void {
  try {
    run();
  } catch (error) {
    check(error, name);
    return;
  }
  throw new AssertionError(`expected ${name ?? "an error"} to be thrown`);
}

export async function rejects(
  promise: Promise<unknown> | (() => Promise<unknown>),
  name?: string,
): Promise<unknown> {
  try {
    await (typeof promise === "function" ? promise() : promise);
  } catch (error) {
    check(error, name);
    return error;
  }
  throw new AssertionError(`expected ${name ?? "a rejection"}`);
}

export async function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function collect<T>(iterable: Iterable<T>): Array<T> {
  return [...iterable];
}

export function hex(buffer: ArrayBuffer | Uint8Array): string {
  return Array.from(
    buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}
