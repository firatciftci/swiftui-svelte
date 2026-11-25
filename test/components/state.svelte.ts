import { SvelteDate } from "svelte/reactivity";

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
  values: {
    number: 1.5,
    boolean: true,
    string: "text",
    array: [1, "two", false],
    object: { b: 2, a: [1] },
    date: new SvelteDate("2026-01-02T03:04:05.006Z"),
  },
});

export function resetState(): void {
  state.items = [1, 2, 3];
  state.show = true;
  state.label = "";
  state.padding = 8;
}
