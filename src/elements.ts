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
type Weight =
  | "ultraLight"
  | "thin"
  | "light"
  | "regular"
  | "medium"
  | "semibold"
  | "bold"
  | "heavy"
  | "black";
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
type Edge = "top" | "bottom" | "leading" | "trailing";
type TransitionName =
  | "opacity"
  | "fade"
  | "scale"
  | "slide"
  | "blur"
  | "move"
  | "push"
  | `move-${Edge}`
  | `push-${Edge}`;
type Transition = TransitionName | `${TransitionName} ${string}`;
type Curve =
  | "default"
  | "linear"
  | "easeIn"
  | "easeOut"
  | "easeInOut"
  | "spring"
  | "bouncy"
  | "smooth"
  | "snappy";
export type AnimationOptions =
  | boolean
  | Curve
  | {
      type?: Curve;
      duration?: number;
      bounce?: number;
      delay?: number;
      speed?: number;
      repeat?: boolean | number;
      autoreverses?: boolean;
    };
type LayerAlignment =
  | "center"
  | "top"
  | "bottom"
  | "leading"
  | "trailing"
  | "topLeading"
  | "topTrailing"
  | "bottomLeading"
  | "bottomTrailing"
  | "leadingFirstTextBaseline"
  | "centerFirstTextBaseline"
  | "trailingFirstTextBaseline"
  | "leadingLastTextBaseline"
  | "centerLastTextBaseline"
  | "trailingLastTextBaseline";
type Modifiers = {
  padding?: number | boolean;
  font?: Font;
  size?: number;
  design?: "default" | "rounded" | "serif" | "monospaced";
  weight?: Weight;
  color?: Color;
  tint?: Color;
  background?: Color;
  radius?: number;
  opacity?: number;
  width?: number;
  height?: number;
  animated?: boolean;
  animation?: AnimationOptions;
  transition?: Transition;
  in?: Transition;
  out?: Transition;
  testid?: string;
  lang?: string;
  dir?: "ltr" | "rtl";
};

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    navstack: Modifiers & { onpop?: (depth: number) => void };
    screen: Modifiers & { title?: string };
    sheet: Modifiers & { detent?: "medium" | "large"; ondismiss?: () => void };
    alert: { title: string; ondismiss?: () => void };
    toolbar: { placement?: "leading" | "trailing" | "bottom" };
    tabview: Modifiers & {
      selection?: string | number;
      onchange?: (selection: string | number) => void;
    };
    tab: Modifiers & {
      title: string;
      symbol?: string;
      value?: string | number;
    };
    swipeactions: { edge?: "leading" | "trailing" };
    vstack: Modifiers & {
      spacing?: number;
      alignment?:
        | "leading"
        | "center"
        | "trailing"
        | "listRowSeparatorLeading"
        | "listRowSeparatorTrailing";
    };
    hstack: Modifiers & {
      spacing?: number;
      alignment?:
        | "top"
        | "center"
        | "bottom"
        | "firstTextBaseline"
        | "lastTextBaseline";
    };
    zstack: Modifiers & { alignment?: LayerAlignment };
    scrollview: Modifiers;
    list: Modifiers;
    spacer: Modifiers & { minlength?: number };
    divider: Modifiers;
    txt: Modifiers & {
      lines?: number;
      align?: "leading" | "center" | "trailing";
      italic?: boolean;
      underline?: boolean;
      strikethrough?: boolean;
      href?: string;
      markdown?: boolean | string;
      kerning?: number;
      tracking?: number;
      linespacing?: number;
      truncation?: "head" | "middle" | "tail";
      minscale?: number;
      selectable?: boolean;
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
      focused?: boolean;
      oninput?: (value: string) => void;
      onsubmit?: () => void;
      onfocus?: () => void;
      onblur?: () => void;
    };
    toggle: Modifiers & {
      checked?: boolean;
      onchange?: (checked: boolean) => void;
    };
    formview: Modifiers;
    sectionview: Modifiers & { header?: string; footer?: string };
    background: { alignment?: LayerAlignment };
    overlay: { alignment?: LayerAlignment };
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
  function __nativeCommit(json: string, animation?: string): void;
  function __nativeNow(): number;
  function __nativeInvoke(id: number, method: string, json: string): void;
  var __svelteReply: (
    request: number,
    rect: { x: number; y: number; width: number; height: number } | null,
  ) => void;
  function __nativeGC(): void;
  function __nativeRequestFrame(): void;
  var __svelteFrame: (time: number) => void;
  function __nativeStats(): {
    nodes: number;
    maxFrameGapMs: number;
    applyMs: number;
  };
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
  function __nativeRandomFill(bytes: Uint8Array<ArrayBuffer>): void;
  function __nativeDigest(
    algorithm: string,
    data: Uint8Array<ArrayBuffer>,
  ): Uint8Array;
  function __nativeEnvironment(): string;
  var __svelteEnvironment: (json: string) => void;
  var __svelteAppEvent: (type: string, payload: unknown) => void;
  function __nativeFetch(
    id: number,
    request: string,
    body: Uint8Array<ArrayBuffer> | null,
    onResponse: (meta: string) => void,
    onData: (chunk: Uint8Array) => void,
    onEnd: (error: string | null) => void,
  ): void;
  function __nativeFetchCancel(id: number): void;
  function __nativeWebSocketOpen(
    id: number,
    url: string,
    protocols: string,
    handlers: {
      open: (protocol: string) => void;
      message: (data: string | Uint8Array) => void;
      sent: (bytes: number) => void;
      close: (code: number, reason: string, wasClean: boolean) => void;
      error: (message: string) => void;
    },
  ): void;
  function __nativeWebSocketSend(
    id: number,
    data: string | Uint8Array<ArrayBuffer>,
  ): void;
  function __nativeWebSocketClose(
    id: number,
    code: number,
    reason: string,
  ): void;
}
