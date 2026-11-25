import { BlobShim, FileShim } from "./blob.ts";
import { DOMExceptionShim } from "./events.ts";

const errorTypes = new Map<string, ErrorConstructor>([
  ["Error", Error],
  ["EvalError", EvalError],
  ["RangeError", RangeError],
  ["ReferenceError", ReferenceError],
  ["SyntaxError", SyntaxError],
  ["TypeError", TypeError],
  ["URIError", URIError],
]);

type TypedArrayConstructor = new (
  buffer: ArrayBuffer,
  byteOffset: number,
  length: number,
) => ArrayBufferView;

function uncloneable(value: unknown): never {
  throw new DOMExceptionShim(
    `${String(value)} could not be cloned.`,
    "DataCloneError",
  );
}

export function structuredCloneShim<T>(
  value: T,
  options: StructuredSerializeOptions = {},
): T {
  const memory = new Map<unknown, unknown>();
  const transfer = options.transfer ?? [];
  for (const item of transfer) {
    if (!(item instanceof ArrayBuffer)) uncloneable(item);
    if (memory.has(item))
      throw new DOMExceptionShim(
        "An ArrayBuffer was transferred twice.",
        "DataCloneError",
      );
    if (item.detached)
      throw new DOMExceptionShim(
        "An ArrayBuffer is detached and could not be cloned.",
        "DataCloneError",
      );
    memory.set(item, item.slice(0, item.byteLength));
  }

  const clone = (input: unknown): unknown => {
    if (typeof input === "symbol" || typeof input === "function")
      uncloneable(input);
    if (input === null || typeof input !== "object") return input;
    if (memory.has(input)) return memory.get(input);
    const remember = <V>(output: V): V => {
      memory.set(input, output);
      return output;
    };
    if (input instanceof Boolean) return remember(new Object(input.valueOf()));
    if (input instanceof Number) return remember(new Object(input.valueOf()));
    if (input instanceof String) return remember(new Object(input.valueOf()));
    if (typeof BigInt === "function" && input instanceof BigInt)
      return remember(new Object(input.valueOf()));
    if (input instanceof Date) return remember(new Date(input));
    if (input instanceof RegExp)
      return remember(new RegExp(input.source, input.flags));
    if (input instanceof ArrayBuffer) {
      if (input.detached) uncloneable(input);
      return remember(input.slice(0, input.byteLength));
    }
    if (ArrayBuffer.isView(input)) {
      const buffer = clone(input.buffer) as ArrayBuffer;
      if (input instanceof DataView)
        return remember(
          new DataView(buffer, input.byteOffset, input.byteLength),
        );
      const TypedArray = input.constructor as TypedArrayConstructor;
      return remember(
        new TypedArray(
          buffer,
          input.byteOffset,
          Number(Reflect.get(input, "length")),
        ),
      );
    }
    if (input instanceof Map) {
      const output = remember(new Map());
      for (const [key, entry] of input) output.set(clone(key), clone(entry));
      return output;
    }
    if (input instanceof Set) {
      const output = remember(new Set());
      for (const entry of input) output.add(clone(entry));
      return output;
    }
    if (input instanceof FileShim) {
      return remember(
        new FileShim([input], input.name, {
          type: input.type,
          lastModified: input.lastModified,
        }),
      );
    }
    if (input instanceof BlobShim)
      return remember(new BlobShim([input], { type: input.type }));
    if (input instanceof DOMExceptionShim)
      return remember(new DOMExceptionShim(input.message, input.name));
    if (input instanceof Error) {
      const ErrorType = errorTypes.get(input.name) ?? Error;
      const output = remember(new ErrorType(input.message));
      if (input.stack != null)
        Object.defineProperty(output, "stack", {
          value: input.stack,
          writable: true,
          configurable: true,
        });
      if (Object.hasOwn(input, "cause")) {
        Object.defineProperty(output, "cause", {
          value: clone(input.cause),
          writable: true,
          configurable: true,
        });
      }
      return output;
    }
    if (
      input instanceof Promise ||
      input instanceof WeakMap ||
      input instanceof WeakSet ||
      (typeof WeakRef === "function" && input instanceof WeakRef)
    ) {
      uncloneable(input);
    }
    if (Array.isArray(input)) {
      const output = remember(Array.from({ length: input.length }));
      for (const key of Object.keys(input))
        Reflect.set(output, key, clone(Reflect.get(input, key)));
      return output;
    }
    const output = remember<Record<string, unknown>>({});
    for (const key of Object.keys(input))
      output[key] = clone(Reflect.get(input, key));
    return output;
  };

  const result = clone(value) as T;
  for (const item of transfer) if (item instanceof ArrayBuffer) item.transfer();
  return result;
}
