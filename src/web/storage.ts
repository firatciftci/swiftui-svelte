export function createStorage(
  initial: Iterable<[string, string]>,
  onChange?: (items: Map<string, string>) => void,
): Storage {
  const items = new Map(initial);
  const changed = (): void => onChange?.(items);
  const methods: Storage = {
    get length() {
      return items.size;
    },
    key(index: number): string | null {
      let position = 0;
      for (const key of items.keys()) {
        if (position++ === Math.trunc(index)) return key;
      }
      return null;
    },
    getItem: (key: unknown): string | null => items.get(String(key)) ?? null,
    setItem(key: unknown, value: unknown): void {
      items.set(String(key), String(value));
      changed();
    },
    removeItem(key: unknown): void {
      if (items.delete(String(key))) changed();
    },
    clear(): void {
      if (items.size === 0) return;
      items.clear();
      changed();
    },
  };
  return new Proxy(methods, {
    get(target, property, receiver) {
      if (typeof property === "symbol" || Reflect.has(target, property))
        return Reflect.get(target, property, receiver) as unknown;
      return items.get(property);
    },
    set(target, property, value) {
      if (typeof property === "symbol" || Reflect.has(target, property))
        return Reflect.set(target, property, value);
      target.setItem(property, String(value));
      return true;
    },
    has: (target, property) =>
      (typeof property === "string" && items.has(property)) ||
      Reflect.has(target, property),
    deleteProperty(target, property) {
      if (typeof property === "string") target.removeItem(property);
      return true;
    },
    ownKeys() {
      const keys: Array<string> = [];
      for (const key of items.keys()) keys.push(key);
      return keys;
    },
    getOwnPropertyDescriptor(target, property) {
      if (typeof property !== "string" || !items.has(property)) return;
      return {
        value: items.get(property),
        writable: true,
        enumerable: true,
        configurable: true,
      };
    },
  });
}
