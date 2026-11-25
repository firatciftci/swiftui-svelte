export function isIterable(value: unknown): value is Iterable<unknown> {
  return (
    typeof value === "object" &&
    value != null &&
    typeof Reflect.get(value, Symbol.iterator) === "function"
  );
}
