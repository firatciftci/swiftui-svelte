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
type NamedColor =
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
  | "black"
  | "clear";
type SystemColor =
  | "systemBackground"
  | "secondarySystemBackground"
  | "tertiarySystemBackground"
  | "systemGroupedBackground"
  | "secondarySystemGroupedBackground"
  | "tertiarySystemGroupedBackground"
  | "label"
  | "secondaryLabel"
  | "tertiaryLabel"
  | "quaternaryLabel"
  | "placeholderText"
  | "separator"
  | "opaqueSeparator"
  | "link"
  | "systemFill"
  | "secondarySystemFill"
  | "tertiarySystemFill"
  | "quaternarySystemFill"
  | "systemGray"
  | "systemGray2"
  | "systemGray3"
  | "systemGray4"
  | "systemGray5"
  | "systemGray6";
export type Color =
  | NamedColor
  | SystemColor
  | `#${string}`
  | `rgb(${string})`
  | `rgba(${string})`
  | `hsl(${string})`
  | `hsla(${string})`;
type UnitPointName =
  | "center"
  | "top"
  | "bottom"
  | "leading"
  | "trailing"
  | "topLeading"
  | "topTrailing"
  | "bottomLeading"
  | "bottomTrailing";
type GradientStop = Color | { color: Color; location: number };
export type ShapeStyle =
  | Color
  | `${NamedColor}.gradient`
  | "tertiary"
  | "quaternary"
  | "quinary"
  | "ultraThinMaterial"
  | "thinMaterial"
  | "regularMaterial"
  | "thickMaterial"
  | "ultraThickMaterial"
  | "bar"
  | { linear: Array<GradientStop>; start?: UnitPointName; end?: UnitPointName }
  | {
      radial: Array<GradientStop>;
      center?: UnitPointName;
      startRadius?: number;
      endRadius?: number;
    }
  | {
      angular: Array<GradientStop>;
      center?: UnitPointName;
      startAngle?: number;
      endAngle?: number;
    };
type ShapeAttributes = Modifiers & {
  fill?: ShapeStyle;
  stroke?: ShapeStyle;
  linewidth?: number;
  linecap?: "butt" | "round" | "square";
  linejoin?: "miter" | "round" | "bevel";
  dash?: Array<number>;
  dashphase?: number;
  fillrule?: "nonzero" | "evenodd";
};
type Corners = { corners?: "continuous" | "circular" };
type SymbolVariant = "fill" | "slash" | "circle" | "square" | "rectangle";
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
type HorizontalAlignment =
  | "leading"
  | "center"
  | "trailing"
  | "listRowSeparatorLeading"
  | "listRowSeparatorTrailing";
type VerticalAlignment =
  | "top"
  | "center"
  | "bottom"
  | "firstTextBaseline"
  | "lastTextBaseline";
type GridItemOptions = { spacing?: number; alignment?: LayerAlignment };
type GridItem =
  | number
  | (GridItemOptions & { fixed: number })
  | (GridItemOptions & { adaptive: number; max?: number })
  | (GridItemOptions & { min?: number; max?: number });
type Pinned = "headers" | "footers" | "both";
export type Size = { width: number; height: number };
export type ScrollGeometry = {
  x: number;
  y: number;
  width: number;
  height: number;
  contentWidth: number;
  contentHeight: number;
};
type ScrollOptions = {
  indicators?: boolean | "automatic" | "visible" | "hidden" | "never";
  bounce?: "automatic" | "always" | "basedOnSize";
  anchor?: UnitPointName;
  onscroll?: (scroll: ScrollGeometry) => void;
};
type TextInput = Modifiers & {
  placeholder?: string;
  focused?: boolean;
  keyboard?:
    | "default"
    | "ascii"
    | "numbersAndPunctuation"
    | "url"
    | "number"
    | "phone"
    | "namePhone"
    | "email"
    | "decimal"
    | "twitter"
    | "webSearch"
    | "asciiNumber";
  contenttype?:
    | "name"
    | "givenName"
    | "middleName"
    | "familyName"
    | "nickname"
    | "jobTitle"
    | "organization"
    | "email"
    | "phone"
    | "url"
    | "username"
    | "password"
    | "newPassword"
    | "oneTimeCode"
    | "streetAddress"
    | "addressLine1"
    | "addressLine2"
    | "city"
    | "state"
    | "postalCode"
    | "country"
    | "creditCardNumber"
    | "location"
    | "birthdate";
  autocapitalize?: "never" | "words" | "sentences" | "characters";
  autocorrect?: boolean;
  submitlabel?:
    | "done"
    | "go"
    | "send"
    | "join"
    | "route"
    | "search"
    | "return"
    | "next"
    | "continue";
  onsubmit?: () => void;
  onfocus?: () => void;
  onblur?: () => void;
};
type TextValue = {
  value?: string;
  debounce?: number;
  oninput?: (value: string) => void;
};
type FieldVariant = "automatic" | "plain" | "roundedBorder";
export type NumberFormat =
  | "number"
  | "integer"
  | "percent"
  | { currency: string };
type Modifiers = {
  padding?: number | boolean;
  font?: Font;
  size?: number;
  design?: "default" | "rounded" | "serif" | "monospaced";
  weight?: Weight;
  color?: ShapeStyle;
  tint?: Color;
  controlsize?: "mini" | "small" | "regular" | "large" | "extraLarge";
  background?: ShapeStyle;
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
  colspan?: number;
  columnalignment?: HorizontalAlignment;
  cellanchor?: UnitPointName;
  onresize?: (size: Size) => void;
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
    vstack: Modifiers & { spacing?: number; alignment?: HorizontalAlignment };
    hstack: Modifiers & { spacing?: number; alignment?: VerticalAlignment };
    zstack: Modifiers & { alignment?: LayerAlignment };
    rectangle: ShapeAttributes;
    roundedrectangle: ShapeAttributes & Corners & { cornerradius?: number };
    unevenroundedrectangle: ShapeAttributes &
      Corners & {
        topleading?: number;
        toptrailing?: number;
        bottomleading?: number;
        bottomtrailing?: number;
      };
    circleshape: ShapeAttributes;
    ellipseshape: ShapeAttributes;
    capsule: ShapeAttributes & Corners;
    pathshape: ShapeAttributes & { d: string; viewbox?: string };
    lazyvstack: Modifiers & {
      spacing?: number;
      alignment?: HorizontalAlignment;
      pinned?: Pinned;
    };
    lazyhstack: Modifiers & {
      spacing?: number;
      alignment?: VerticalAlignment;
      pinned?: Pinned;
    };
    lazyvgrid: Modifiers & {
      columns?: number | Array<GridItem>;
      spacing?: number;
      alignment?: HorizontalAlignment;
      pinned?: Pinned;
    };
    lazyhgrid: Modifiers & {
      rows?: number | Array<GridItem>;
      spacing?: number;
      alignment?: VerticalAlignment;
      pinned?: Pinned;
    };
    grid: Modifiers & {
      alignment?: LayerAlignment;
      spacing?: number;
      hspacing?: number;
      vspacing?: number;
    };
    gridrow: Modifiers & { alignment?: VerticalAlignment };
    viewthatfits: Modifiers & { axes?: "horizontal" | "vertical" | "both" };
    group: Modifiers;
    groupbox: Modifiers & { title?: string };
    controlgroup: Modifiers & { title?: string };
    disclosuregroup: Modifiers & {
      title?: string;
      expanded?: boolean;
      ontoggle?: (expanded: boolean) => void;
    };
    scrollview: Modifiers &
      ScrollOptions & {
        axes?: "vertical" | "horizontal" | "both";
        snap?: "paging" | "view";
      };
    list: Modifiers & ScrollOptions;
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
    asyncimage: Modifiers & {
      src: string;
      fit?: "fit" | "fill" | "stretch" | "tile";
      onload?: () => void;
      onerror?: (message: string) => void;
    };
    imageview: Modifiers & {
      name?: string;
      file?: string;
      fit?: "fit" | "fill" | "stretch" | "tile";
      renderingmode?: "original" | "template";
      label?: string;
      decorative?: boolean;
    };
    labelview: Modifiers & {
      title?: string;
      symbol?: string;
      image?: string;
      variant?: "automatic" | "titleOnly" | "iconOnly" | "titleAndIcon";
    };
    linkview: Modifiers & { href: string; title?: string };
    sharelink: Modifiers & {
      item: string;
      subject?: string;
      message?: string;
      title?: string;
    };
    placeholder: Record<string, never>;
    failure: Record<string, never>;
    icon: Record<string, never>;
    btn: Modifiers & {
      variant?:
        | "automatic"
        | "borderless"
        | "plain"
        | "bordered"
        | "prominent"
        | "glass"
        | "glassProminent";
      role?: "destructive" | "cancel" | "confirm" | "close";
      bordershape?:
        | "automatic"
        | "capsule"
        | "roundedRectangle"
        | "circle"
        | number;
      repeat?: boolean;
      onclick?: () => void;
    };
    sfsymbol: Modifiers & {
      name: string;
      label?: string;
      value?: number;
      variant?: SymbolVariant | `${SymbolVariant} ${SymbolVariant}`;
      rendering?: "monochrome" | "hierarchical" | "palette" | "multicolor";
      colors?: Array<Color>;
      effect?:
        | "bounce"
        | "pulse"
        | "variableColor"
        | "breathe"
        | "rotate"
        | "wiggle"
        | "scale";
      trigger?: string | number | boolean;
      active?: boolean;
    };
    textfield: TextInput &
      (
        | (TextValue & {
            format?: undefined;
            variant?: FieldVariant;
            axis?: "horizontal" | "vertical";
            lines?: number | [number, number];
          })
        | {
            format: NumberFormat;
            variant?: FieldVariant;
            value?: number | null;
            oninput?: (value: number | null) => void;
          }
      );
    securefield: TextInput & TextValue & { variant?: FieldVariant };
    texteditor: Omit<TextInput, "placeholder"> & TextValue;
    toggle: Modifiers & {
      checked?: boolean;
      variant?: "automatic" | "switch" | "button" | "checkbox";
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
