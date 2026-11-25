import { SvelteDate } from "svelte/reactivity";

function values(): Record<string, unknown> {
  return {
    number: 1.5,
    boolean: true,
    string: "text",
    array: [1, "two", false],
    object: { b: 2, a: [1] },
    date: new SvelteDate("2026-01-02T03:04:05.006Z"),
    big: 12n,
    map: new Map<string, unknown>([
      ["a", 1],
      ["b", new Set(["x"])],
    ]),
    special: [NaN, Infinity, undefined, null, -0],
    none: null,
    nested: { at: new Date("2026-01-02T03:04:05.006Z"), skip: undefined },
  };
}

export const state: {
  items: Array<number>;
  show: boolean;
  label: string;
  padding: number | undefined;
  values: Record<string, unknown>;
} = $state({
  items: [1, 2, 3],
  show: true,
  label: "",
  padding: 8,
  values: values(),
});

export function resetState(): void {
  state.items = [1, 2, 3];
  state.show = true;
  state.label = "";
  state.padding = 8;
  state.values = values();
}
