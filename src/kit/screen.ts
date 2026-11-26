import { getContext } from "svelte";
import type { Screen } from "./types.ts";

export const screenKey = Symbol("swiftui-svelte.screen");

export function useScreen(): Screen {
  const screen = getContext<Screen | undefined>(screenKey);
  if (screen == null) {
    throw new Error(
      "useScreen() must be called from a page or layout in src/routes.",
    );
  }
  return screen;
}
