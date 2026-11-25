import { SvelteMap } from "svelte/reactivity";

const prefix = "swiftui-svelte.restorable.";
const restored = new SvelteMap<string, { value: unknown }>();

function isCompatible(value: unknown, initial: unknown): boolean {
  if (initial == null) return true;
  if (Array.isArray(initial)) return Array.isArray(value);
  return value != null && typeof value === typeof initial;
}

function read(key: string): unknown {
  const saved = localStorage.getItem(prefix + key);
  if (saved == null) return undefined;
  try {
    return JSON.parse(saved);
  } catch {
    return undefined;
  }
}

export function restorable<T>(
  key: string,
  initial: T,
  isValid: (value: unknown) => value is T = (value): value is T =>
    isCompatible(value, initial),
): { value: T } {
  const existing = restored.get(key);
  if (existing != null && isValid(existing.value)) {
    return existing as { value: T };
  }
  const saved = read(key);
  const state = $state({
    value: saved !== undefined && isValid(saved) ? saved : initial,
  });
  restored.set(key, state);
  $effect.root(() => {
    $effect(() => {
      localStorage.setItem(
        prefix + key,
        JSON.stringify($state.snapshot(state.value)),
      );
    });
  });
  return state;
}
