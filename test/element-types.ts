import type { SvelteHTMLElements } from "svelte/elements";

export const text: SvelteHTMLElements["txt"] = { balanced: true };
// @ts-expect-error balanced balances the lines of a txt and does nothing on a stack
export const stack: SvelteHTMLElements["vstack"] = { balanced: true };
