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
  width?: number;
  height?: number;
  animated?: boolean;
  testid?: string;
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
    txt: Modifiers & {
      lines?: number;
      align?: "leading" | "center" | "trailing";
    };
    asyncimage: Modifiers & { src: string; fit?: "fit" | "fill" };
    btn: Modifiers & {
      variant?: "automatic" | "borderless" | "bordered" | "prominent";
      role?: "destructive" | "cancel";
      onclick?: () => void;
    };
    sfsymbol: Modifiers & { name: string; label?: string };
    textfield: Modifiers & {
      value?: string;
      placeholder?: string;
      debounce?: number;
      oninput?: (value: string) => void;
      onsubmit?: () => void;
    };
    toggle: Modifiers & {
      checked?: boolean;
      onchange?: (checked: boolean) => void;
    };
    formview: Modifiers;
    sectionview: Modifiers & { header?: string; footer?: string };
    picker: Modifiers & {
      label?: string;
      value?: string | number;
      variant?:
        | "automatic"
        | "menu"
        | "segmented"
        | "wheel"
        | "inline"
        | "navigation";
      onchange?: (value: string | number) => void;
    };
    choice: { value: string | number; symbol?: string };
    slider: Modifiers & {
      value?: number;
      min?: number;
      max?: number;
      step?: number;
      oninput?: (value: number) => void;
      onchange?: (value: number) => void;
    };
    stepper: Modifiers & {
      value?: number;
      min?: number;
      max?: number;
      step?: number;
      onchange?: (value: number) => void;
    };
    datepicker: Modifiers & {
      value?: Date | string;
      min?: Date | string;
      max?: Date | string;
      components?: "date" | "time" | "datetime";
      variant?: "automatic" | "compact" | "graphical" | "wheel";
      onchange?: (value: Date) => void;
    };
    progressview: Modifiers & { value?: number; total?: number };
  }
}

declare global {
  function __nativeCommit(json: string): void;
  function __nativeNow(): number;
  function __nativeGC(): void;
  function __nativeRequestFrame(): void;
  var __svelteFrame: (time: number) => void;
  function __nativeStats(): { nodes: number; maxFrameGapMs: number };
  function __nativeLog(
    level: "log" | "info" | "warn" | "error" | "debug",
    message: string,
  ): void;
  var __svelteDispatch: (id: number, type: string, payload: unknown) => void;
  var __svelteMount: (mountId: number, name: string, json: string) => void;
  var __svelteProps: (mountId: number, json: string) => void;
  var __svelteUnmount: (mountId: number) => void;
  function __nativeAction(mountId: number, name: string, json: string): void;
  function __nativeStorageLoad(): string;
  function __nativeStorageSave(json: string): void;
  function __nativeFetch(
    request: string,
    callback: (error: string | null, response?: NativeFetchResponse) => void,
  ): void;
  type NativeFetchResponse = {
    status: number;
    url: string;
    headers: Record<string, string>;
    body: string;
  };
}
