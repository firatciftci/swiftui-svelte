export type { SvelteHTMLElements } from "svelte/elements";

type Font =
  | "largeTitle"
  | "title"
  | "title2"
  | "title3"
  | "headline"
  | "subheadline"
  | "body"
  | "callout"
  | "footnote"
  | "caption"
  | "caption2";
type Weight = "regular" | "medium" | "semibold" | "bold" | "heavy";
type Color =
  | "primary"
  | "secondary"
  | "accent"
  | "red"
  | "orange"
  | "yellow"
  | "green"
  | "mint"
  | "teal"
  | "cyan"
  | "blue"
  | "indigo"
  | "purple"
  | "pink"
  | "brown"
  | "gray"
  | "white"
  | "black";
type Modifiers = {
  padding?: number | boolean;
  font?: Font;
  weight?: Weight;
  color?: Color;
  tint?: Color;
  background?: Color;
  radius?: number;
  opacity?: number;
  animated?: boolean;
};

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    navstack: Modifiers & { onpop?: (depth: number) => void };
    screen: Modifiers & { title?: string };
    sheet: Modifiers & { detent?: "medium" | "large"; ondismiss?: () => void };
    alert: { title: string; ondismiss?: () => void };
    toolbar: { placement?: "leading" | "trailing" | "bottom" };
    tabview: Modifiers;
    tab: Modifiers & { title: string; symbol?: string };
    swipeactions: { edge?: "leading" | "trailing" };
    vstack: Modifiers & {
      spacing?: number;
      alignment?: "leading" | "center" | "trailing";
    };
    hstack: Modifiers & {
      spacing?: number;
      alignment?: "top" | "center" | "bottom";
    };
    zstack: Modifiers;
    scrollview: Modifiers;
    list: Modifiers;
    spacer: Modifiers;
    divider: Modifiers;
    txt: Modifiers;
    btn: Modifiers & {
      variant?: "automatic" | "borderless" | "bordered" | "prominent";
      role?: "destructive" | "cancel";
      onclick?: () => void;
    };
    sfsymbol: Modifiers & { name: string };
    textfield: Modifiers & {
      value?: string;
      placeholder?: string;
      oninput?: (value: string) => void;
      onsubmit?: () => void;
    };
    toggle: Modifiers & {
      checked?: boolean;
      onchange?: (checked: boolean) => void;
    };
  }
}

declare global {
  function __nativeCommit(json: string): void;
  function __nativeNow(): number;
  function __nativeGC(): void;
  function __nativeStats(): { nodes: number; maxFrameGapMs: number };
  function __nativeLog(
    level: "log" | "info" | "warn" | "error" | "debug",
    message: string,
  ): void;
  var __svelteDispatch: (id: number, type: string, payload: unknown) => void;
}
