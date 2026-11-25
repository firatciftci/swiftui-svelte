export function isIterable(value: unknown): value is Iterable<unknown> {
  return (
    typeof value === "object" &&
    value != null &&
    typeof Reflect.get(value, Symbol.iterator) === "function"
  );
}

export function isAsyncIterable<T>(
  value: Iterable<T> | AsyncIterable<T>,
): value is AsyncIterable<T> {
  return Reflect.has(value, Symbol.asyncIterator);
}
