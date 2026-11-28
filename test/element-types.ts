import type { SvelteHTMLElements } from "svelte/elements";

export const text: SvelteHTMLElements["txt"] = { balanced: true };
// @ts-expect-error balanced balances the lines of a txt and does nothing on a stack
export const stack: SvelteHTMLElements["vstack"] = { balanced: true };
export const row: SvelteHTMLElements["hstack"] = {
  css: true,
  axis: "vertical",
};
// @ts-expect-error only CSS stacks read css, so it does nothing on a txt
export const flexText: SvelteHTMLElements["txt"] = { css: true };
