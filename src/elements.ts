import type { HostEnvironment } from "./web/environment.ts";
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
/** A color: a SwiftUI or UIKit system color name, or a CSS color string. */
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
type GradientStop =
  | Color
  | {
      /** The color of the stop. */
      color: Color;
      /** The position of the stop along the gradient, from 0 to 1. */
      location: number;
    };
/** A fill or foreground style: a color, a hierarchical style, a material, a color's gradient, or a gradient object. */
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
  | {
      /** The stops of a linear gradient, from `start` to `end`. */
      linear: Array<GradientStop>;
      /** The point where the gradient starts, such as `topLeading`. */
      start?: UnitPointName;
      /** The point where the gradient ends, such as `bottomTrailing`. */
      end?: UnitPointName;
    }
  | {
      /** The stops of a radial gradient, which grows outward from `center`. */
      radial: Array<GradientStop>;
      /** The point the gradient is centered on, such as `center`. */
      center?: UnitPointName;
      /** The radius in points where the gradient starts. */
      startRadius?: number;
      /** The radius in points where the gradient ends. */
      endRadius?: number;
    }
  | {
      /** The stops of an angular gradient, which sweeps around `center`. */
      angular: Array<GradientStop>;
      /** The point the gradient sweeps around, such as `center`. */
      center?: UnitPointName;
      /** The angle in degrees where the sweep starts. */
      startAngle?: number;
      /** The angle in degrees where the sweep ends. */
      endAngle?: number;
    };
type ShapeAttributes = Modifiers & {
  /** The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style. */
  fill?: ShapeStyle;
  /** The style of the shape's outline, centered on the shape's edge. */
  stroke?: ShapeStyle;
  /** The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. */
  strokeborder?: ShapeStyle;
  /** The width of the outline in points. Defaults to 1. */
  linewidth?: number;
  /** The shape of the outline's ends: `butt`, `round`, or `square`. */
  linecap?: "butt" | "round" | "square";
  /** The shape of the outline's corners: `miter`, `round`, or `bevel`. */
  linejoin?: "miter" | "round" | "bevel";
  /** The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`. */
  dash?: Array<number>;
  /** The offset in points into the dash pattern where the outline starts. Defaults to 0. */
  dashphase?: number;
  /** How the fill decides which areas are inside the shape: `nonzero` or `evenodd`. */
  fillrule?: "nonzero" | "evenodd";
};
type BlendMode =
  | "normal"
  | "multiply"
  | "screen"
  | "overlay"
  | "darken"
  | "lighten"
  | "color-dodge"
  | "color-burn"
  | "soft-light"
  | "hard-light"
  | "difference"
  | "exclusion"
  | "hue"
  | "saturation"
  | "color"
  | "luminosity"
  | "plus-lighter"
  | "plus-darker";
type Corners = {
  /** The corner style: `continuous` (the default) or `circular`. */
  corners?: "continuous" | "circular";
};
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
  | "snappy"
  | "timingCurve";
/** An animation: a curve name, or an object that sets the curve and its timing. */
export type AnimationOptions =
  | boolean
  | Curve
  | {
      /** The animation curve. */
      type?: Curve;
      /** The length of the animation in milliseconds. */
      duration?: number;
      /** The bounce of a spring curve, from -1 to 1. */
      bounce?: number;
      /** The delay before the animation starts, in milliseconds. */
      delay?: number;
      /** The speed multiplier of the animation. */
      speed?: number;
      /** A number of times to repeat the animation, or `true` to repeat it forever. */
      repeat?: boolean | number;
      /** Whether the animation reverses on each repeat. */
      autoreverses?: boolean;
      /** The control points of a `timingCurve`, given as `[x1, y1, x2, y2]`, the same as a CSS `cubic-bezier`. Required with `type: "timingCurve"`. */
      curve?: [number, number, number, number];
    };
type ButtonFeedback = Omit<Modifiers, "pressed" | "hovered">;
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
type GridItemOptions = {
  /** The space in points between this column or row and the next one. */
  spacing?: number;
  /** The alignment of the content inside the column or row. */
  alignment?: LayerAlignment;
};
type GridItem =
  | number
  | (GridItemOptions & {
      /** A column or row of this fixed width in points. */
      fixed: number;
    })
  | (GridItemOptions & {
      /** As many columns or rows of at least this width in points as fit. */
      adaptive: number;
      /** The maximum width in points. */
      max?: number;
    })
  | (GridItemOptions & {
      /** The minimum width in points. */
      min?: number;
      /** The maximum width in points. */
      max?: number;
    });
type Pinned = "headers" | "footers" | "both";
/** A width and height in points. */
export type Size = {
  /** The width in points. */
  width: number;
  /** The height in points. */
  height: number;
};
/** The scroll position and sizes that `onscroll` receives, in points. */
export type ScrollGeometry = {
  /** The horizontal scroll offset from the leading edge. */
  x: number;
  /** The vertical scroll offset from the top edge. */
  y: number;
  /** The width of the visible area. */
  width: number;
  /** The height of the visible area. */
  height: number;
  /** The width of the scrollable content. */
  contentWidth: number;
  /** The height of the scrollable content. */
  contentHeight: number;
};
type ScrollOptions = {
  /** Whether the scroll indicators show: `automatic`, `visible`, `hidden`, or `never`, or a boolean where `false` hides them. */
  indicators?: boolean | "automatic" | "visible" | "hidden" | "never";
  /** When the content bounces past its edges: `automatic`, `always`, or `basedOnSize`, which bounces only when the content is larger than the view. */
  bounce?: "automatic" | "always" | "basedOnSize";
  /** The point the scroll starts at, as a unit point such as `bottom`, which suits a chat. */
  anchor?: UnitPointName;
  /** Runs as the content scrolls, with the scroll position and sizes in points. */
  onscroll?: (scroll: ScrollGeometry) => void;
  /** Runs when the user pulls to refresh. If it returns a promise, the spinner stays until the promise settles. */
  onrefresh?: () => Promise<unknown> | void;
  /** Stops the content from scrolling, and keeps it in place. */
  scrolldisabled?: boolean;
  /** Runs when the scroll phase changes, with `phase`: `idle`, `tracking` (a finger is on the content), `interacting`, `decelerating`, or `animating`. */
  onscrollphase?: (event: ScrollPhaseEvent) => void;
};
/** The payload of `onscrollphase`: the scroll phase the content is in now. */
export type ScrollPhaseEvent = {
  /** The phase: `idle`, `tracking`, `interacting`, `decelerating`, or `animating`. */
  phase: "idle" | "tracking" | "interacting" | "decelerating" | "animating";
};
/** The rows that moved in an `onmove` call: the positions they came from, and the position they moved to. */
export type RowMove = {
  /** The positions of the rows that moved, counted before the move. */
  from: Array<number>;
  /** The position the rows moved to, counted before the move. */
  to: number;
};
type RowEdits = {
  /** Runs when the user deletes rows, with the positions of the deleted rows among the element's children. */
  ondelete?: (indices: Array<number>) => void;
  /** Runs when the user moves a row, with the rows that moved and the position they moved to. */
  onmove?: (move: RowMove) => void;
};
type ListSelection =
  | {
      /** Set to `false`, or leave it out, to allow only one selected row. */
      multiple?: false;
      /** The `tag` of the selected row, or `null` when nothing is selected. */
      selection?: string | number | null;
      /** Runs when the selection changes, with the selected row's `tag`, or `null`. */
      onselectionchange?: (selection: string | number | null) => void;
    }
  | {
      /** Set to `true` to let the user select several rows. */
      multiple: true;
      /** The `tag`s of the selected rows. */
      selection?: Array<string | number>;
      /** Runs when the selection changes, with the array of selected `tag`s. */
      onselectionchange?: (selection: Array<string | number>) => void;
    };
type Inset = number | boolean;
type Insets =
  | Inset
  | {
      /** The inset of the top edge, in points. */
      top?: Inset;
      /** The inset of the leading edge, in points. */
      leading?: Inset;
      /** The inset of the bottom edge, in points. */
      bottom?: Inset;
      /** The inset of the trailing edge, in points. */
      trailing?: Inset;
      /** The inset of the leading and trailing edges, in points. A shorthand for `leading` and `trailing`. */
      horizontal?: Inset;
      /** The inset of the top and bottom edges, in points. A shorthand for `top` and `bottom`. */
      vertical?: Inset;
    };
type Length = number | "infinity";
type Point = { x?: number; y?: number };
type TextInput = Modifiers & {
  /** The text shown in the field while it's empty. */
  placeholder?: string;
  /** The color of the placeholder text, such as a named color or a CSS color. Without it, the placeholder uses the system's secondary color. */
  placeholdercolor?: ShapeStyle;
  /** Whether the field has keyboard focus. Use `bind:focused` with the `TextField` component to bind it. */
  focused?: boolean;
  /** The keyboard to show, such as `email`, `url`, `number`, `decimal`, or `phone`. */
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
  /** What the text is, such as `email`, `username`, `password`, or `oneTimeCode`, so iOS can offer AutoFill and saved passwords. */
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
  /** How the text is capitalized: `never`, `words`, `sentences`, or `characters`. */
  autocapitalize?: "never" | "words" | "sentences" | "characters";
  /** Whether autocorrection is on. Set it to `false` to turn it off. */
  autocorrect?: boolean;
  /** The label on the Return key, such as `done`, `go`, `next`, `search`, or `send`. */
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
  /** Runs when the user presses Return, after any pending input is sent. */
  onsubmit?: () => void;
  /** Runs when the field gains keyboard focus. */
  onfocus?: () => void;
  /** Runs when the field loses keyboard focus. */
  onblur?: () => void;
};
type TextValue = {
  /** The text in the field. Leave it out to let the field keep whatever the user types. */
  value?: string;
  /** Milliseconds to wait after the user stops typing before `oninput` runs. Defaults to 0, which runs it on every keystroke. */
  debounce?: number;
  /** Runs with the new text on each keystroke, or after the `debounce` delay. */
  oninput?: (value: string) => void;
};
type BarVisibility = boolean | "automatic" | "visible" | "hidden";
type ToolbarPlacement =
  | "leading"
  | "trailing"
  | "bottom"
  | "principal"
  | "status"
  | "keyboard"
  | "navigation"
  | "primaryAction"
  | "secondaryAction"
  | "confirmationAction"
  | "cancellationAction"
  | "destructiveAction"
  | "automatic";
type Detent = "medium" | "large" | number;
type ColumnWidth = number | { min?: number; ideal?: number; max?: number };
type SplitVisibility = "automatic" | "all" | "doubleColumn" | "detailOnly";
type SplitColumn = "sidebar" | "content" | "detail";
/** A token in a `searchable` field: a plain string, or an object with a `label`, and optionally an `id` and `symbol`. */
export type SearchToken =
  | string
  | {
      /** A unique identifier for the token. */
      id?: string | number;
      /** The text shown on the token. */
      label: string;
      /** The SF Symbol name shown on the token. */
      symbol?: string;
    };
/** A scope button for a `searchable` field: a string, or an object with a `value` and an optional `title`. */
export type SearchScope =
  | string
  | {
      /** The value that `selectedscope` and `onscopechange` use for this scope. */
      value: string;
      /** The text shown on the scope button. Defaults to `value`. */
      title?: string;
    };
type PresentationOptions = {
  /** The heights the user can drag the presentation to: `medium`, `large`, a fraction of the screen such as `0.25`, or a height in points such as `300`. Defaults to `large`. */
  detents?: Array<Detent>;
  /** Shows the drag handle at the top: `visible`, `hidden`, or `automatic`. */
  dragindicator?: "automatic" | "visible" | "hidden";
  /** Whether the user can dismiss the presentation by swiping it away. Set it to `false` to keep it open. */
  dismissible?: boolean;
  /** Whether the user can use the content behind the presentation: `true`, `false`, or a detent such as `0.25` to allow it only up to that height. */
  backgroundinteraction?:
    | boolean
    | "automatic"
    | "enabled"
    | "disabled"
    | Detent;
  /** The corner radius of the presentation in points. */
  cornerradius?: number;
  /** The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background (`regular` or `clear` on iOS 26, and a material before that). */
  presentationbackground?:
    | ShapeStyle
    | "clear"
    | { glass?: "regular" | "clear" };
  /** Runs when the user dismisses the presentation, so you can update your state. */
  ondismiss?: () => void;
};
type FieldVariant = "automatic" | "plain" | "roundedBorder";
/** How a number field shows its value: `number`, `integer`, `percent`, or `{ currency }` with an ISO currency code. */
export type NumberFormat =
  | "number"
  | "integer"
  | "percent"
  | {
      /** An ISO 4217 currency code, such as `EUR`. */
      currency: string;
    };
type ClipShape =
  | "rectangle"
  | "circle"
  | "capsule"
  | "ellipse"
  | number
  | { cornerradius: number }
  | {
      /** The radius in points of the top leading corner. */
      topleading?: number;
      /** The radius in points of the top trailing corner. */
      toptrailing?: number;
      /** The radius in points of the bottom leading corner. */
      bottomleading?: number;
      /** The radius in points of the bottom trailing corner. */
      bottomtrailing?: number;
    }
  | {
      /** SVG path data for the shape. */
      d: string;
      /** The SVG `viewBox` that the path scales to fit. */
      viewbox?: string;
    };
type EdgeSet = Edge | "all" | "horizontal" | "vertical";
type SafeAreaIgnoring =
  | boolean
  | "container"
  | "keyboard"
  | EdgeSet
  | Array<EdgeSet>
  | {
      /** The safe area regions to extend under: `all`, `container`, or `keyboard`. */
      regions?: "all" | "container" | "keyboard";
      /** The edges to extend under, as an edge, an array of edges, `all`, `horizontal`, or `vertical`. */
      edges?: EdgeSet | Array<EdgeSet>;
    };
type AccessibilityTrait =
  | "button"
  | "header"
  | "link"
  | "image"
  | "selected"
  | "modal"
  | "toggle"
  | "staticText"
  | "searchField"
  | "summaryElement"
  | "updatesFrequently"
  | "playsSound"
  | "startsMediaSession"
  | "keyboardKey"
  | "allowsDirectInteraction"
  | "causesPageTurn";
type DynamicTypeSize = HostEnvironment["dynamicTypeSize"];
type SensoryFeedback =
  | "success"
  | "warning"
  | "error"
  | "selection"
  | "increase"
  | "decrease"
  | "start"
  | "stop"
  | "alignment"
  | "levelChange"
  | "impact"
  | {
      /** The feedback type, which is `impact`. */
      type?: "impact";
      /** The weight of the impact: `light`, `medium`, or `heavy`. */
      weight?: "light" | "medium" | "heavy";
      /** How rigid the impact feels: `rigid`, `solid`, or `soft`. */
      flexibility?: "rigid" | "solid" | "soft";
      /** The strength of the impact, from 0 to 1. */
      intensity?: number;
    };
type GesturePoint = { x: number; y: number };
type GesturePhase = "changed" | "ended";
/** The payload of `onhover`: the pointer's phase, and its position in points unless the phase is `exit`. */
export type HoverEvent = {
  /** `enter` when the pointer arrives, `move` while it moves over the element, and `exit` when it leaves. */
  phase: "enter" | "move" | "exit";
  /** The pointer's `{ x, y }` in the element's coordinates. */
  location?: GesturePoint;
};
/** The payload of `ondrag`: the drag's phase, positions in points, and velocity in points per second. */
export type DragEvent = {
  /** `changed` while the finger moves, and `ended` when it lifts. */
  phase: GesturePhase;
  /** The current position of the finger in the element's coordinates. */
  location: GesturePoint;
  /** The position where the drag started. */
  start: GesturePoint;
  /** The distance the finger has moved since the drag started. */
  translation: GesturePoint;
  /** The speed of the finger in points per second. */
  velocity: GesturePoint;
  /** Where the drag would end if the finger kept moving at its current speed and slowed down. */
  predictedEnd: GesturePoint;
};
/** The payload of `onmagnify`: the pinch's phase, its magnification, and its velocity. */
export type MagnifyEvent = {
  /** `changed` while the pinch continues, and `ended` when the fingers lift. */
  phase: GesturePhase;
  /** The scale of the pinch relative to its start. */
  magnification: number;
  /** The rate of change of the magnification per second. */
  velocity: number;
};
/** The payload of `onrotate`: the rotation's phase, its angle, and its velocity. */
export type RotateEvent = {
  /** `changed` while the rotation continues, and `ended` when the fingers lift. */
  phase: GesturePhase;
  /** The angle of the rotation in degrees since it started. */
  degrees: number;
  /** The rate of rotation in degrees per second. */
  velocity: number;
};
/** The attributes that every element accepts, mapped to SwiftUI view modifiers. */
type Modifiers = {
  /** Pads the element. A number pads every edge by that many points, an object such as `{ horizontal: 20, top: 4 }` pads each edge separately, and a bare `padding` adds 16 points. A negative value works as it does in SwiftUI: the element's frame shrinks by that much, and content that fills the space it's offered, such as a shape, draws that far past the frame. Use it for shadows and backgrounds that spread beyond their element. */
  padding?: Insets;
  /** The text style, which follows Dynamic Type, such as `headline` or `caption`. Applies to all the text inside the element. */
  font?: Font;
  /** The PostScript name of a font to use instead of a system font, such as `Georgia-Bold`. With `size`, the font has that fixed size. With `font`, the size scales with Dynamic Type relative to that text style. */
  fontname?: string;
  /** PostScript names of fonts to try, in order, for characters that `fontname` doesn't have, such as an Arabic font for Arabic text. Each fallback is used when the font before it lacks the character. */
  fontfallbacks?: Array<string>;
  /** A font size in points. Without `fontname`, it's a fixed size, like `.system(size:)`, and it doesn't follow Dynamic Type. With `fontname` and `font`, it's the base size that scales with Dynamic Type relative to that text style. */
  size?: number;
  /** The font design: `default`, `rounded`, `serif`, or `monospaced`. */
  design?: "default" | "rounded" | "serif" | "monospaced";
  /** The font weight, from `ultraLight` through `black`. */
  weight?: Weight;
  /** Draws the text in italics. */
  italic?: boolean;
  /** The foreground style of the content, such as a named color, a CSS color, or a gradient. */
  color?: ShapeStyle;
  /** The tint of the controls inside the element. Takes a color only. */
  tint?: Color;
  /** The size of the controls inside the element: `mini`, `small`, `regular`, `large`, or `extraLarge`. */
  controlsize?: "mini" | "small" | "regular" | "large" | "extraLarge";
  /** The background style, such as a color, a material, or a gradient, drawn behind the element. */
  background?: ShapeStyle;
  /** Rounds the corners of the element to this radius in points. */
  radius?: number;
  /** The opacity of the element, from 0 (transparent) to 1 (opaque). Defaults to 1. */
  opacity?: number;
  /** Adds brightness to the element, from -1 (darker) to 1 (brighter). Defaults to 0, which leaves the element unchanged. */
  brightness?: number;
  /** Multiplies the colors of the element by this color, which darkens or tints the element. Takes a color only. */
  colormultiply?: Color;
  /** How the element's colors blend with the views behind it, such as `multiply` or `screen`. Defaults to `normal`. */
  blendmode?: BlendMode;
  /** Draws the element and its children as one layer before blending, so `opacity` and `blendmode` apply to the group as a whole. */
  compositinggroup?: boolean;
  /** Brightens the element by blending a copy of it over itself with the plus-lighter mode at this opacity, from 0 to 1. Unlike brightness, which adds the same amount to every color, the copy's opacity sets the strength, so 0.125 adds an eighth of the element's color again. */
  lighten?: number;
  /** Draws a soft inner edge along the rounded corners set by `radius`, like an inset shadow. Combine it with `opacity` and `pressed`, such as `opacity={0}` with `pressed={{ opacity: 1 }}`, to fade the edge in while a button is pressed. */
  insetshadow?: boolean;
  /** The look of this element while the `btn` around it is pressed. Any modifier here overrides the same attribute on this element while the press lasts, such as `background`, `radius`, `border`, `shadow`, `colormultiply`, `scale`, `opacity`, `brightness`, or `color`. Set a value to `false` to remove it, such as `shadow: false`. `animation` sets how the change is animated. On a `btn`, the same overrides apply to the label's direct children, and a child's own `pressed` value wins over them. */
  pressed?: ButtonFeedback;
  /** The look of this element while the pointer is over the `btn` around it. It takes the same values as `pressed`, and `pressed` wins while both apply. */
  hovered?: ButtonFeedback;
  /** A fixed width in points. */
  width?: number;
  /** A fixed height in points. */
  height?: number;
  /** The minimum width in points, or `infinity` to fill the available width. */
  minwidth?: Length;
  /** The ideal width in points, or `infinity`, used as the preferred size in a flexible frame. */
  idealwidth?: Length;
  /** The maximum width in points, or `infinity` to grow to fill the available width. */
  maxwidth?: Length;
  /** The minimum height in points, or `infinity` to fill the available height. */
  minheight?: Length;
  /** The ideal height in points, or `infinity`, used as the preferred size in a flexible frame. */
  idealheight?: Length;
  /** The maximum height in points, or `infinity` to grow to fill the available height. */
  maxheight?: Length;
  /** Where the content sits inside a flexible frame, such as `center` or `topLeading`. */
  framealignment?: LayerAlignment;
  /** The ratio of width to height that the element keeps. */
  aspectratio?: number;
  /** Fits the element inside its space (`fit`), or fills the space (`fill`), keeping the aspect ratio. */
  contentmode?: "fit" | "fill";
  /** Keeps the element at its ideal size instead of letting its parent shrink it: `true` for both axes, or `horizontal` or `vertical`. */
  fixedsize?: boolean | "horizontal" | "vertical";
  /** The priority the element has when its parent doesn't have room for every child. Higher values keep their size first. */
  layoutpriority?: number;
  /** Whether the element responds to touches and the pointer. Set it to `false` to let touches pass through it to the views behind. */
  allowshittesting?: boolean;
  /** Moves the element by `{ x, y }` points without changing the layout around it. */
  offset?: Point;
  /** Places the element's center at `{ x, y }` points in its parent's coordinate space. */
  position?: Point;
  /** Rotates the element by a number of degrees around `rotationanchor`. */
  rotation?: number;
  /** The point the element rotates around, as a unit point such as `center` or `topLeading`. Defaults to `center`. */
  rotationanchor?: UnitPointName;
  /** Scales the element by a number, or by `{ x, y }` for each axis, around `scaleanchor`. */
  scale?: number | Point;
  /** The point the element scales around, as a unit point such as `center`. Defaults to `center`. */
  scaleanchor?: UnitPointName;
  /** The stacking order of the element among its siblings. Higher values draw in front. */
  zindex?: number;
  /** Clips the element to a shape: `rectangle`, `circle`, `capsule`, `ellipse`, a corner radius in points, an object with corner radii, or an SVG path as `{ d, viewbox }`. */
  clipshape?: ClipShape;
  /** The shape that responds to taps, using the same values as `clipshape`. */
  contentshape?: ClipShape;
  /** Draws a border in a color, or as `{ color, width }`, where `width` is in points and defaults to 1. */
  border?: Color | { color?: ShapeStyle; width?: number };
  /** Draws a shadow. A number sets the blur radius, and an object sets the `color`, `radius`, `x`, and `y` of the shadow in points. `false` draws no shadow, which removes the shadow that a button's label has. */
  shadow?:
    | false
    | number
    | Color
    | {
        /** The color of the shadow. */
        color?: Color;
        /** The blur radius of the shadow in points. */
        radius?: number;
        /** The horizontal offset of the shadow in points. */
        x?: number;
        /** The vertical offset of the shadow in points. */
        y?: number;
      };
  /** Blurs the element by this radius in points. */
  blur?: number;
  /** Hides the element but keeps its space in the layout. */
  hidden?: boolean;
  /** Disables every control inside the element. */
  disabled?: boolean;
  /** Lets the element extend under the safe area: `true` for every edge, `keyboard` or `container` for only that region, an edge, an array of edges, or `{ regions, edges }`. */
  ignoressafearea?: SafeAreaIgnoring;
  /** Animates the element's children as they're added, removed, or reordered, using the curve from `animation`. */
  animated?: boolean;
  /** The animation curve for `animated` and `transition`: a curve name, or an object with `type`, `duration`, `delay`, `bounce`, `speed`, `repeat`, and `autoreverses`. */
  animation?: AnimationOptions;
  /** Turns off animations for the element and everything inside it, so its changes happen at once. */
  disablesanimations?: boolean;
  /** The transition that plays when the element is added and removed, such as `scale opacity` or `move-top`. */
  transition?: Transition;
  /** The transition that plays only when the element is added. */
  in?: Transition;
  /** The transition that plays only when the element is removed. */
  out?: Transition;
  /** The accessibility identifier for UI tests. On a container, it applies to the children too, unless `a11ychildren` is `contain`. */
  testid?: string;
  /** The label that VoiceOver reads for the element, in place of its own label. */
  a11ylabel?: string;
  /** The value that VoiceOver reads for the element, such as a rating. */
  a11yvalue?: string | number;
  /** A hint that VoiceOver reads after the label, describing what happens when the user activates the element. */
  a11yhint?: string;
  /** The names that Voice Control accepts for the element, in addition to its label. */
  a11yinputlabels?: Array<string>;
  /** Adds accessibility traits, such as `button`, `header`, or `selected`, to the element. */
  a11ytraits?: AccessibilityTrait | Array<AccessibilityTrait>;
  /** Removes accessibility traits from the element, using the same names as `a11ytraits`. */
  a11yremovetraits?: AccessibilityTrait | Array<AccessibilityTrait>;
  /** Marks the element as a heading: `true` for no specific level, or a level from `1` to `6`. */
  a11yheading?: true | "unspecified" | 1 | 2 | 3 | 4 | 5 | 6;
  /** The VoiceOver order of the element. Elements with higher priorities are visited first. */
  a11ysortpriority?: number;
  /** How the children are grouped for VoiceOver: `combine` merges them into one element, `contain` groups them under the element, and `ignore` hides them behind the element's own label. */
  a11ychildren?: "combine" | "contain" | "ignore";
  /** Hides the element from assistive technologies. */
  a11yhidden?: boolean;
  /** The names of custom actions that VoiceOver lists in its Actions rotor. Each one calls `ona11yaction` with its name. */
  a11yactions?: Array<string>;
  /** Runs when the user picks one of the `a11yactions` from the VoiceOver rotor, with that action's name. */
  ona11yaction?: (name: string) => void;
  /** Runs when VoiceOver activates the element by default, such as with a double tap. */
  ona11yactivate?: () => void;
  /** Runs when the VoiceOver escape gesture is used on the element. */
  ona11yescape?: () => void;
  /** Runs when the VoiceOver magic tap gesture is used on the element. */
  ona11ymagictap?: () => void;
  /** Runs when the VoiceOver increment or decrement gesture is used on the element, with `increment` or `decrement`. */
  ona11yadjust?: (direction: "increment" | "decrement") => void;
  /** The number of grid columns the element spans inside a `grid`. */
  colspan?: number;
  /** The alignment of the element's whole column inside a `grid`. */
  columnalignment?: HorizontalAlignment;
  /** Where the element sits inside its grid cell, as a unit point such as `topLeading`. */
  cellanchor?: UnitPointName;
  /** The text that fills the search field when the user taps this suggestion inside a `searchable`. */
  completion?: string;
  /** Identifies a list row for selection, as a string or a number. `onselectionchange` receives this tag. */
  tag?: string | number;
  /** The insets of a list row: a number, or `{ top, leading, bottom, trailing }`, with `horizontal` and `vertical` as shorthands. */
  rowinsets?: Insets;
  /** Shows or hides the separator below a list row: `visible`, `hidden`, or `automatic`, or a boolean. */
  rowseparator?: BarVisibility;
  /** The color of a list row's separator. */
  rowseparatortint?: Color;
  /** The background style of a list row. */
  rowbackground?: ShapeStyle;
  /** Keeps the user from deleting the row with a swipe or in edit mode. */
  deletedisabled?: boolean;
  /** Keeps the user from moving the row in edit mode. */
  movedisabled?: boolean;
  /** Runs with the element's `{ width, height }` in points when it first appears and whenever its size changes. */
  onresize?: (size: Size) => void;
  /** Runs when the element is tapped, with the tap's `{ x, y }` position in the element's coordinates. */
  ontap?: (location: GesturePoint) => void;
  /** The number of taps that trigger `ontap`. Defaults to 1, so 2 means a double tap. */
  tapcount?: number;
  /** Runs when the user holds a finger down on the element for `longpressduration` seconds. */
  onlongpress?: () => void;
  /** How long the user must hold a finger down, in seconds, before `onlongpress` runs. Defaults to 0.5. */
  longpressduration?: number;
  /** Runs as the user drags the element, with the drag's phase, position, and velocity. */
  ondrag?: (drag: DragEvent) => void;
  /** The distance in points the finger must move before a drag starts. Defaults to 10. */
  dragdistance?: number;
  /** Runs as the pointer moves over the element: `enter` when it arrives, `move` as it moves, and `exit` when it leaves. `location` is the pointer's `{ x, y }` in points, and it's missing on `exit`. */
  onhover?: (event: HoverEvent) => void;
  /** Starts a namespace for the `matchedid` elements inside this element. Elements with the same `matchedid` animate from one position to the other when one replaces the other. */
  namespace?: boolean;
  /** Matches this element with the element that has the same `matchedid` in the same namespace, so the two animate between their positions when one replaces the other. */
  matchedid?: string;
  /** Runs when the element scrolls into or out of view in its `scrollview` or `list`, with `visible`. */
  onscrollvisibility?: (event: { visible: boolean }) => void;
  /** The share of the element that must be on screen to count as visible, from 0 to 1. Defaults to 0, which counts any part of the element. */
  visibilitythreshold?: number;
  /** Runs during a pinch gesture, with the pinch's phase, magnification, and velocity. */
  onmagnify?: (magnify: MagnifyEvent) => void;
  /** Runs during a two-finger rotation, with the rotation's phase, angle, and velocity. */
  onrotate?: (rotate: RotateEvent) => void;
  /** Runs when SwiftUI shows the element, such as when a list row scrolls into view. */
  onappear?: () => void;
  /** Runs when SwiftUI hides the element. */
  ondisappear?: () => void;
  /** Runs when the element appears, like SwiftUI's `.task`. The `AbortSignal` it receives aborts when the element disappears or when `taskid` changes. */
  ontask?: (signal: AbortSignal) => unknown;
  /** Runs `ontask` again whenever this value changes. The previous run is canceled first. */
  taskid?: string | number | boolean | null;
  /** The locale of the element and everything inside it, such as `ar` or `en-US`. SwiftUI uses it to format dates and numbers, and text inside the element is shaped for that language, so that Turkish `f` and dotted `i` stay apart. */
  lang?: string;
  /** The layout direction of the element and everything inside it: `ltr` or `rtl`. */
  dir?: "ltr" | "rtl";
  /** The haptic feedback to play each time `feedbacktrigger` changes: a name such as `success` or `impact`, or an object describing an impact. */
  sensoryfeedback?: SensoryFeedback;
  /** The value to watch for `sensoryfeedback`. Feedback plays each time it changes. */
  feedbacktrigger?: unknown;
  /** Forces `light` or `dark` mode on the element and everything inside it. */
  colorscheme?: "light" | "dark";
  /** Asks the window, sheet, or popover that contains the element to use `light` or `dark` mode. */
  preferredcolorscheme?: "light" | "dark";
  /** Pins the Dynamic Type size, such as `xLarge`, or keeps it within `{ min, max }`. */
  dynamictypesize?:
    | DynamicTypeSize
    | {
        /** The smallest Dynamic Type size. */
        min?: DynamicTypeSize;
        /** The largest Dynamic Type size. */
        max?: DynamicTypeSize;
      };
  /** Draws Liquid Glass behind the element on iOS 26 and later, in a capsule unless a `shape` is set. Earlier versions draw the element without glass. */
  glasseffect?:
    | boolean
    | "regular"
    | "clear"
    | "identity"
    | {
        /** The glass style: `regular`, `clear`, or `identity`. */
        variant?: "regular" | "clear" | "identity";
        /** The tint of the glass. */
        tint?: Color;
        /** Whether the glass responds to touches. */
        interactive?: boolean;
        /** The shape of the glass, using the same values as `clipshape`. */
        shape?: ClipShape;
      };
  /** Identifies a glass shape inside a `glasseffectcontainer`, so one shape can morph into another as elements appear and disappear. */
  glassid?: string | number;
  /** Groups elements inside a `glasseffectcontainer` so that they share one glass shape. */
  glassunion?: string | number;
  /** Whether scrolling hides the keyboard: `automatic`, `immediately`, `interactively`, or `never`. */
  scrolldismisseskeyboard?:
    | "automatic"
    | "immediately"
    | "interactively"
    | "never";
};

/** The attributes that every element accepts. */
export type ElementModifiers = Modifiers;

/**
The type of a native component element. `Attributes` lists its attributes, and each key of `Events` becomes an `on` handler that receives its payload. A built-in modifier with the same name as one of them is replaced by the component's own.
*/
export type NativeElement<
  Attributes extends Record<string, unknown> = Record<never, never>,
  Events extends Record<string, unknown> = Record<never, never>,
> = Omit<Modifiers, keyof Attributes | `on${keyof Events & string}`> &
  Attributes & {
    [Event in keyof Events & string as `on${Event}`]?: (
      payload: Events[Event],
    ) => void;
  };

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    /** A `NavigationStack`: the root of a navigation hierarchy, where each `screen` after the first is pushed on top of the stack. */
    navstack: Modifiers & {
      /** Runs when the user pops a screen, with the number of pushed screens that are left, so you can trim your state to match. */
      onpop?: (depth: number) => void;
      /** The width of the stack when it's a column of a `navsplitview`, in points, or `{ min, ideal, max }`. */
      columnwidth?: ColumnWidth;
    };
    /** A `NavigationSplitView`: a sidebar, content, and detail layout that collapses into a stack on iPhone. */
    navsplitview: Modifiers & {
      /** The visibility of the columns: `automatic`, `all`, `doubleColumn`, or `detailOnly`. */
      visibility?: SplitVisibility;
      /** Runs when SwiftUI or the user changes the column visibility, with the new value. */
      onvisibilitychange?: (visibility: SplitVisibility) => void;
      /** The column that shows on iPhone, where the columns collapse into a stack: `sidebar`, `content`, or `detail`. */
      compactcolumn?: SplitColumn;
      /** Runs when the user goes back to another column on iPhone, with the column they went back to. */
      oncompactcolumnchange?: (column: SplitColumn) => void;
      /** The split view style: `automatic`, `balanced`, or `prominentDetail`. */
      variant?: "automatic" | "balanced" | "prominentDetail";
    };
    /** A screen in a navigation stack, a tab, or a split view column, with options for its title and bars. */
    screen: Modifiers & {
      /** The width of the screen when it's a column of a `navsplitview`, in points, or `{ min, ideal, max }`. */
      columnwidth?: ColumnWidth;
      /** The title in the navigation bar. */
      title?: string;
      /** A line under the title, shown on iOS 26 and later. */
      subtitle?: string;
      /** How the title is displayed: `automatic`, `inline`, or `large`. */
      titledisplaymode?: "automatic" | "inline" | "large";
      /** Hides the back button. */
      backbuttonhidden?: boolean;
      /** Shows, hides, or automates the navigation bar: `visible`, `hidden`, or `automatic`. */
      navbarvisibility?: BarVisibility;
      /** Shows, hides, or automates the tab bar: `visible`, `hidden`, or `automatic`. */
      tabbarvisibility?: BarVisibility;
      /** Fills the navigation bar with a color or a material. */
      navbarbackground?: ShapeStyle;
    };
    /** A `.sheet` presented from the nearest screen, tab, or presentation for as long as it's rendered. */
    sheet: Modifiers &
      PresentationOptions & {
        /** A single height: `medium` allows the medium and large heights, and `large` allows only the large height. Use `detents` to set several. */
        detent?: "medium" | "large";
      };
    /** A `.fullScreenCover` presented for as long as it's rendered. */
    fullscreencover: Modifiers & {
      /** The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background. */
      presentationbackground?: PresentationOptions["presentationbackground"];
      /** Whether the user can dismiss the cover. */
      dismissible?: boolean;
      /** Runs when the cover is dismissed, so you can update your state. */
      ondismiss?: () => void;
    };
    /** A `.popover` anchored to the element it's inside, such as a `btn`. */
    popover: Modifiers &
      PresentationOptions & {
        /** The edge of the anchor that the arrow points from: `top`, `bottom`, `leading`, or `trailing`. */
        arrowedge?: Edge;
        /** How the popover adapts on iPhone, where it opens as a sheet by default: `automatic`, `none`, `popover`, `sheet`, or `fullScreenCover`. */
        adaptation?:
          | "automatic"
          | "none"
          | "popover"
          | "sheet"
          | "fullScreenCover";
      };
    /** An `.inspector` shown as a column beside the content on iPad and as a sheet on iPhone, for as long as it's rendered. */
    inspector: Modifiers &
      PresentationOptions & {
        /** The width of the inspector column on iPad, in points, or `{ min, ideal, max }`. */
        columnwidth?: ColumnWidth;
      };
    /** An `.alert` presented for as long as it's rendered, with `txt` children as its message and `btn` children as its actions. */
    alert: {
      /** The title of the alert. */
      title: string;
      /** Runs when the alert is dismissed, so you can update your state. */
      ondismiss?: () => void;
    };
    /** A `.confirmationDialog` anchored to the element it's inside, with `btn` children as its actions. */
    confirmationdialog: {
      /** The title of the dialog. */
      title: string;
      /** Shows or hides the title: `automatic`, `visible`, or `hidden`. */
      titlevisibility?: "automatic" | "visible" | "hidden";
      /** Runs when the dialog is dismissed, so you can update your state. */
      ondismiss?: () => void;
    };
    /** A `.searchable` search field, added to the navigation bar of the nearest screen. */
    searchable: {
      /** The text in the search field. */
      value?: string;
      /** Runs with the new text on each change. */
      oninput?: (value: string) => void;
      /** Runs when the user presses Search or picks a suggestion. */
      onsubmit?: () => void;
      /** The placeholder text of the search field. */
      prompt?: string;
      /** Where the search field appears: `automatic`, `toolbar`, `sidebar`, or `navigationBarDrawer`. */
      placement?: "automatic" | "toolbar" | "sidebar" | "navigationBarDrawer";
      /** In the `navigationBarDrawer` placement, `always` keeps the field showing on iOS 26 and later. `automatic` lets it hide until the user scrolls down. */
      drawer?: "automatic" | "always";
      /** Whether the user is searching, such as after tapping the field. Use `bind:presented` with the `Searchable` component to bind it. */
      presented?: boolean;
      /** Runs when the user starts or cancels a search, with the new `presented` value. */
      onpresentedchange?: (presented: boolean) => void;
      /** The tokens in the search field. */
      tokens?: Array<SearchToken>;
      /** Runs when the user adds or removes a token, with the new list of tokens. */
      ontokenschange?: (tokens: Array<SearchToken>) => void;
      /** Tokens the user can add, shown as suggestions. */
      suggestedtokens?: Array<SearchToken>;
      /** The scope buttons shown below the search field. */
      scopes?: Array<SearchScope>;
      /** The `value` of the selected scope. */
      selectedscope?: string;
      /** Runs when the user picks a scope, with the scope's value. */
      onscopechange?: (scope: string) => void;
      /** When the scope buttons appear: `automatic`, `onTextEntry`, or `onSearchPresentation`. */
      scopeactivation?: "automatic" | "onTextEntry" | "onSearchPresentation";
      /** On iOS 26 and later, collapses the search field into a toolbar button. */
      minimize?: boolean;
    };
    /** A `.toolbar` whose children become toolbar items of the element it sits in, such as a screen, a dialog, or a section of a page. Put it next to a `textfield` with `placement="keyboard"` to show a bar above the keyboard while the field has focus. */
    toolbar: {
      /** Where the toolbar items go: `trailing` (the default), `leading`, `principal`, `bottom`, `keyboard`, or a semantic placement such as `primaryAction`. */
      placement?: ToolbarPlacement;
    };
    /** A `ToolbarSpacer` that separates toolbar items on iOS 26 and later. */
    toolbarspacer: {
      /** The placement of the toolbar that the spacer sits in. Use the same placement as the toolbar items around it. */
      placement?: ToolbarPlacement;
      /** `flexible` pushes the items apart, and `fixed` leaves a fixed gap between them. */
      variant?: "flexible" | "fixed";
    };
    /** A `TabView` that shows the `tab` whose `value` matches `selection`. */
    tabview: Modifiers & {
      /** The `value` of the selected tab. Without it, the first tab is selected. */
      selection?: string | number;
      /** Runs when the user switches tabs, with the `value` of the new tab. */
      onchange?: (selection: string | number) => void;
      /** The tab view style: `automatic`, `page`, `sidebarAdaptable`, or `tabBarOnly`. */
      variant?: "automatic" | "page" | "sidebarAdaptable" | "tabBarOnly";
      /** Shows page dots below the tabs when `variant` is `page`: `automatic`, `always`, or `never`. */
      indexdisplay?: "automatic" | "always" | "never";
      /** On iOS 26 and later, shrinks the tab bar while the user scrolls: `automatic`, `never`, `onScrollDown`, or `onScrollUp`. */
      minimize?: "automatic" | "never" | "onScrollDown" | "onScrollUp";
    };
    /** A `TabSection` that groups `tab` children under a heading. */
    tabsection: {
      /** The title of the section. On iPad with `sidebarAdaptable`, it's a group in the sidebar. */
      title: string;
    };
    /** A `Tab` that appears in the nearest `tabview`. */
    tab: Modifiers & {
      /** The title of the tab. */
      title: string;
      /** The SF Symbol name for the tab's icon. */
      symbol?: string;
      /** The value that `selection` and `onchange` use for this tab. Without it, the tab's position, starting at 0, is used. */
      value?: string | number;
      /** A number or a short label shown on the tab. `0` or an empty string hides it. */
      badge?: string | number;
      /** `search` makes this the search tab, which iOS 26 sets apart at the end of the tab bar. */
      role?: "search";
    };
    /** A `.swipeActions` modifier that adds its `btn` children as the swipe actions of the enclosing list row. */
    swipeactions: {
      /** The edge of the row that the swipe starts from: `leading` or `trailing`. */
      edge?: "leading" | "trailing";
    };
    /** A `.contextMenu` that opens its children as a menu when the user touches and holds the element, or right-clicks it on Mac. */
    contextmenu: Record<string, never>;
    /** The `.contextMenu` preview: a custom view shown above the menu in place of the element. */
    preview: Record<string, never>;
    /** A `VStack`: lays out its children in a vertical column. */
    vstack: Modifiers & {
      /** The space between children, in points. Leave it out for SwiftUI's default spacing. */
      spacing?: number;
      /** The horizontal alignment of the children, such as `leading`, `center`, or `trailing`. */
      alignment?: HorizontalAlignment;
    };
    /** An `HStack`: lays out its children in a horizontal row. */
    hstack: Modifiers & {
      /** The space between children, in points. Leave it out for SwiftUI's default spacing. */
      spacing?: number;
      /** The vertical alignment of the children: `top`, `center`, `bottom`, `firstTextBaseline`, or `lastTextBaseline`. */
      alignment?: VerticalAlignment;
    };
    /** A wrapping layout: it puts its children in rows and starts a new row when the next child doesn't fit the width, the way words wrap in a paragraph. `spacing` sets the gap between children in a row, `linespacing` sets the gap between rows, and `alignment` sets how each row is aligned. */
    flowstack: Modifiers & {
      /** The space between children in a row, in points. Defaults to 8. */
      spacing?: number;
      /** The space between rows, in points. Defaults to `spacing`. */
      linespacing?: number;
      /** How each row sits in the width: `leading`, `center`, or `trailing`. */
      alignment?: "leading" | "center" | "trailing";
    };
    /** A `ZStack`: layers its children on top of each other. */
    zstack: Modifiers & {
      /** The alignment of the children on both axes, such as `center`, `topLeading`, or `leadingFirstTextBaseline`. */
      alignment?: LayerAlignment;
    };
    /** A `Rectangle` shape. */
    rectangle: ShapeAttributes;
    /** A `RoundedRectangle` shape. */
    roundedrectangle: ShapeAttributes &
      Corners & {
        /** The corner radius in points. Defaults to 8. */
        cornerradius?: number;
      };
    /** An `UnevenRoundedRectangle` shape, with its own radius for each corner. */
    unevenroundedrectangle: ShapeAttributes &
      Corners & {
        /** The radius in points of the top leading corner. Defaults to 0. */
        topleading?: number;
        /** The radius in points of the top trailing corner. Defaults to 0. */
        toptrailing?: number;
        /** The radius in points of the bottom leading corner. Defaults to 0. */
        bottomleading?: number;
        /** The radius in points of the bottom trailing corner. Defaults to 0. */
        bottomtrailing?: number;
      };
    /** A `Circle` shape. */
    circleshape: ShapeAttributes;
    /** An `Ellipse` shape. */
    ellipseshape: ShapeAttributes;
    /** A `Capsule` shape, with fully rounded ends. */
    capsule: ShapeAttributes & Corners;
    /** A `Path` shape drawn from SVG path data. */
    pathshape: ShapeAttributes & {
      /** SVG path data for the shape. Every path command is supported, including arcs. */
      d: string;
      /** The SVG `viewBox`, such as `0 0 24 24`. With it, the path scales to fit the frame. Without it, the path is drawn at its own coordinates. */
      viewbox?: string;
    };
    /** A `LazyVStack`: a vertical stack that creates its children as they scroll into view. */
    lazyvstack: Modifiers & {
      /** The space between children, in points. Leave it out for SwiftUI's default spacing. */
      spacing?: number;
      /** The horizontal alignment of the children, such as `leading`, `center`, or `trailing`. */
      alignment?: HorizontalAlignment;
      /** Keeps the headers, the footers, or both on screen while their rows scroll: `headers`, `footers`, or `both`. */
      pinned?: Pinned;
    };
    /** A `LazyHStack`: a horizontal stack that creates its children as they scroll into view. */
    lazyhstack: Modifiers & {
      /** The space between children, in points. Leave it out for SwiftUI's default spacing. */
      spacing?: number;
      /** The vertical alignment of the children: `top`, `center`, `bottom`, `firstTextBaseline`, or `lastTextBaseline`. */
      alignment?: VerticalAlignment;
      /** Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`. */
      pinned?: Pinned;
    };
    /** A `LazyVGrid`: a grid of columns that creates its children as they scroll into view. */
    lazyvgrid: Modifiers & {
      /** The columns: a number of equal flexible columns, or an array of column items. An item is a number for a fixed width, `{ min, max }` for a flexible column, `{ fixed }` for a fixed width, or `{ adaptive }` for as many columns of at least that width as fit. */
      columns?: number | Array<GridItem>;
      /** The space between columns and rows, in points. */
      spacing?: number;
      /** The horizontal alignment of the content in each column. */
      alignment?: HorizontalAlignment;
      /** Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`. */
      pinned?: Pinned;
    };
    /** A `LazyHGrid`: a grid of rows that creates its children as they scroll into view. */
    lazyhgrid: Modifiers & {
      /** The rows: a number of equal flexible rows, or an array of row items. An item is a number for a fixed height, `{ min, max }` for a flexible row, `{ fixed }` for a fixed height, or `{ adaptive }` for as many rows of at least that height as fit. */
      rows?: number | Array<GridItem>;
      /** The space between rows and columns, in points. */
      spacing?: number;
      /** The vertical alignment of the content in each row. */
      alignment?: VerticalAlignment;
      /** Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`. */
      pinned?: Pinned;
    };
    /** A `Grid`: lays out its `gridrow` children as a table whose columns line up across rows. */
    grid: Modifiers & {
      /** The alignment of each child within its grid cell, such as `center` or `topLeading`. */
      alignment?: LayerAlignment;
      /** The horizontal and vertical space between cells, in points. `hspacing` and `vspacing` override each one. */
      spacing?: number;
      /** The horizontal space between columns, in points. Overrides `spacing`. */
      hspacing?: number;
      /** The vertical space between rows, in points. Overrides `spacing`. */
      vspacing?: number;
    };
    /** A `GridRow`: one row of a `grid`. */
    gridrow: Modifiers & {
      /** The vertical alignment of the cells in this row. */
      alignment?: VerticalAlignment;
    };
    /** A `ViewThatFits`: shows the first child that fits in the available space. */
    viewthatfits: Modifiers & {
      /** The axes checked for fit: `horizontal`, `vertical`, or `both`. */
      axes?: "horizontal" | "vertical" | "both";
    };
    /** A `Group`: applies its modifiers to its children without adding a container. */
    group: Modifiers;
    /** A `GroupBox`: draws its children in a box. */
    groupbox: Modifiers & {
      /** The title shown above the box. Use a `label` child for a custom title. */
      title?: string;
    };
    /** A `ControlGroup`: joins its controls, such as buttons, into one control. */
    controlgroup: Modifiers & {
      /** The title of the group. Use a `label` child for a custom title. */
      title?: string;
    };
    /** A `DisclosureGroup`: shows its children when the user expands it. */
    disclosuregroup: Modifiers & {
      /** The title of the group. Use a `label` child for a custom title. */
      title?: string;
      /** Whether the group is expanded. Use `bind:expanded` with the `DisclosureGroup` component to bind it. */
      expanded?: boolean;
      /** Runs when the user expands or collapses the group, with the new `expanded` value. */
      ontoggle?: (expanded: boolean) => void;
    };
    /** A `ScrollView`: scrolls its children, vertically by default. */
    scrollview: Modifiers &
      ScrollOptions & {
        /** The directions in which the content scrolls: `vertical` (the default), `horizontal`, or `both`. */
        axes?: "vertical" | "horizontal" | "both";
        /** Stops scrolling at each screen-sized page with `paging`, or at the start of each child of the stack inside it with `view`. */
        snap?: "paging" | "view";
      };
    /** A `List`: a scrolling list of rows that can be selected, edited, and refreshed. */
    list: Modifiers &
      ScrollOptions &
      RowEdits &
      ListSelection & {
        /** The list style: `automatic`, `plain`, `inset`, `grouped`, `insetGrouped`, or `sidebar`. */
        variant?:
          | "automatic"
          | "plain"
          | "inset"
          | "grouped"
          | "insetGrouped"
          | "sidebar";
        /** Turns edit mode on or off. Use `bind:editing` with the `List` component to bind it. */
        editing?: boolean;
        /** Runs when SwiftUI turns edit mode on or off, with the new `editing` value. */
        oneditingchange?: (editing: boolean) => void;
        /** Shows or hides the section index along the trailing edge, for sections that have an `indexlabel`. */
        sectionindex?: BarVisibility;
      };
    /** A `Spacer`: takes up the free space along the axis of its stack. */
    spacer: Modifiers & {
      /** The minimum length of the spacer in points. It never shrinks below this length. */
      minlength?: number;
    };
    /** A `Divider`: a thin line that separates content. */
    divider: Modifiers;
    /** A `Text`: displays text. Its `txt` children style spans of it, and it can render Markdown. */
    txt: Modifiers & {
      /** The maximum number of lines. Leave it out for no limit. */
      lines?: number;
      /** The alignment of wrapped lines: `leading`, `center`, or `trailing`. */
      align?: "leading" | "center" | "trailing";
      /** Underlines the text. */
      underline?: boolean;
      /** Draws a line through the text. */
      strikethrough?: boolean;
      /** Makes the text a link that opens this URL in the browser. */
      href?: string;
      /** Renders the text as inline Markdown: bold, italic, strikethrough, code, and links. Set it with no value to use the element's own text as the source. */
      markdown?: boolean | string;
      /** How spaces and line breaks are handled: `normal` collapses them, `pre-line` keeps line breaks, and `pre` keeps every space. */
      whitespace?: "normal" | "pre-line" | "pre";
      /** Adjusts the space between letters, in points. */
      kerning?: number;
      /** Adjusts the tracking of the text, which is the space between letters, in points. */
      tracking?: number;
      /** Moves the text up or down from the baseline, in points. A positive value raises the text, and a negative value lowers it. */
      baselineoffset?: number;
      /** The line style of the underline: `solid`, `dotted`, or `dashed`. Applies when `underline` is set. */
      underlinestyle?: "solid" | "dotted" | "dashed";
      /** The color of the underline. Applies when `underline` is set. */
      underlinecolor?: Color;
      /** Uses digits of equal width, so numbers that change don't shift the text around them. */
      monospaceddigit?: boolean;
      /** The extra space between lines, in points. */
      linespacing?: number;
      /** Where the text is cut off when it doesn't fit: `head`, `middle`, or `tail`. */
      truncation?: "head" | "middle" | "tail";
      /** The smallest fraction of the font size that the text can shrink to before it's truncated, such as `0.5`. */
      minscale?: number;
      /** Lets the user select and copy the text. */
      selectable?: boolean;
    };
    /** An `AsyncImage`: loads an image from `src` and shows it in the element's frame. */
    asyncimage: Modifiers & {
      /** The URL of the image to load. */
      src: string;
      /** Scales the image: `fit` keeps its proportions inside the frame, `fill` covers the frame, `stretch` fills it exactly, and `tile` repeats it. Defaults to `fit`. */
      fit?: "fit" | "fill" | "stretch" | "tile";
      /** Runs when the image has loaded and appears. */
      onload?: () => void;
      /** Runs when the image can't be loaded, with the error message. */
      onerror?: (message: string) => void;
    };
    /** An `Image`: shows an image from the asset catalog or the app bundle. */
    imageview: Modifiers & {
      /** The name of an image in the asset catalog. */
      name?: string;
      /** The path of an image file in the app bundle, such as `photos/beach.jpg`. */
      file?: string;
      /** How the image is scaled into its frame: `fit`, `fill`, `stretch`, or `tile`. Without it, the image keeps its own size. */
      fit?: "fit" | "fill" | "stretch" | "tile";
      /** `template` draws the image in the foreground color, and `original` draws it as it is. */
      renderingmode?: "original" | "template";
      /** How smoothly the image is scaled: `none`, `low`, `medium`, or `high`. Use `high` for logos and other raster art drawn much smaller than its pixel size. */
      interpolation?: "none" | "low" | "medium" | "high";
      /** The accessibility label that VoiceOver reads. Without it, VoiceOver reads the name of an asset-catalog image. */
      label?: string;
      /** Hides the image from VoiceOver. */
      decorative?: boolean;
    };
    /** A `Label`: shows a title with an icon. */
    labelview: Modifiers & {
      /** The title of the label. */
      title?: string;
      /** The SF Symbol name for the icon. */
      symbol?: string;
      /** The name of an asset-catalog image for the icon. */
      image?: string;
      /** What the label shows: `automatic`, `titleOnly`, `iconOnly`, or `titleAndIcon`. */
      variant?: "automatic" | "titleOnly" | "iconOnly" | "titleAndIcon";
    };
    /** A `Link`: opens its `href` in the browser when tapped. */
    linkview: Modifiers & {
      /** The URL to open in the browser. */
      href: string;
      /** The text of the link. Use children instead to set a custom label. */
      title?: string;
    };
    /** A `ShareLink`: opens the share sheet for its `item` when tapped. */
    sharelink: Modifiers & {
      /** The URL or text to share. */
      item: string;
      /** The subject line of a shared email. */
      subject?: string;
      /** The message that is shared with the item. */
      message?: string;
      /** The text of the link. Use children instead to set a custom label. */
      title?: string;
    };
    /** The content that an `asyncimage` shows while the image loads. Its children are the content. */
    placeholder: Record<string, never>;
    /** The content that an `asyncimage` shows when the image can't be loaded. Its children are the content. */
    failure: Record<string, never>;
    /** The icon of a `labelview`. Its children are the icon. */
    icon: Record<string, never>;
    /** A `Button`: runs `onclick` when tapped. */
    btn: Modifiers & {
      /** The button style: `automatic`, `borderless` (the default), `plain`, `bordered`, `prominent`, `glass`, or `glassProminent`. The glass styles need iOS 26 and fall back to `bordered` and `prominent` on earlier versions. */
      variant?:
        | "automatic"
        | "borderless"
        | "plain"
        | "bordered"
        | "prominent"
        | "glass"
        | "glassProminent";
      /** The role of the button: `destructive` or `cancel`, or `confirm` and `close` on iOS 26 and later. */
      role?: "destructive" | "cancel" | "confirm" | "close";
      /** The shape of a bordered or glass button: `automatic`, `capsule`, `roundedRectangle`, `circle`, or a corner radius in points. */
      bordershape?:
        | "automatic"
        | "capsule"
        | "roundedRectangle"
        | "circle"
        | number;
      /** Runs `onclick` again and again while the button is held down, as a stepper does. */
      repeat?: boolean;
      /** Runs when the button is tapped. */
      onclick?: () => void;
    };
    /** An SF Symbol, rendered as an `Image(systemName:)`. */
    sfsymbol: Modifiers & {
      /** The SF Symbol name, such as `trash` or `wifi`. */
      name: string;
      /** The accessibility label that VoiceOver reads, such as `Delete to-do`. Without it, VoiceOver reads the symbol's built-in description. */
      label?: string;
      /** A value from 0 to 1 that fills a variable symbol, such as `wifi`, part of the way. */
      value?: number;
      /** Symbol variants: `fill`, `slash`, `circle`, `square`, or `rectangle`. Combine them with a space, such as `circle fill`. */
      variant?: SymbolVariant | `${SymbolVariant} ${SymbolVariant}`;
      /** The rendering mode: `monochrome`, `hierarchical`, `palette`, or `multicolor`. */
      rendering?: "monochrome" | "hierarchical" | "palette" | "multicolor";
      /** Up to three colors for the `palette` rendering mode. */
      colors?: Array<Color>;
      /** An animation for the symbol: `bounce`, `pulse`, `variableColor`, `breathe`, `rotate`, `wiggle`, or `scale`. Repeating effects run while `active` is `true`. */
      effect?:
        | "bounce"
        | "pulse"
        | "variableColor"
        | "breathe"
        | "rotate"
        | "wiggle"
        | "scale";
      /** A value that plays `effect` once each time it changes. `bounce` works only this way, and `scale` ignores it. */
      trigger?: string | number | boolean;
      /** Whether a repeating `effect` runs. Defaults to `true`. */
      active?: boolean;
    };
    /** A `TextField`: an editable text field, or a number field when `format` is set. */
    textfield: TextInput &
      (
        | (TextValue & {
            /** Leave out `format` for a text field. */
            format?: undefined;
            /** The look of the field: `automatic`, `plain`, or `roundedBorder`. */
            variant?: FieldVariant;
            /** Set to `vertical` to let the field grow as the user types more lines, up to `lines`. */
            axis?: "horizontal" | "vertical";
            /** The maximum number of lines when `axis` is `vertical`, such as `4`, or a range such as `[2, 4]` for a minimum and a maximum. */
            lines?: number | [number, number];
          })
        | {
            /** How the number is formatted: `number`, `integer`, `percent`, or `{ currency }` with an ISO currency code, such as `EUR`. */
            format: NumberFormat;
            /** The look of the field: `automatic`, `plain`, or `roundedBorder`. */
            variant?: FieldVariant;
            /** The number in the field, or `null` when it's empty. */
            value?: number | null;
            /** Runs when the user presses Return or leaves the field, with the parsed number, or `null` if they cleared it. */
            oninput?: (value: number | null) => void;
          }
      );
    /** A `SecureField`: a text field that hides what the user types, for passwords. */
    securefield: TextInput &
      TextValue & {
        /** The look of the field: `automatic`, `plain`, or `roundedBorder`. */
        variant?: FieldVariant;
      };
    /** A `TextEditor`: an editable area for many lines of text that scrolls. Give it a `height`. */
    texteditor: Omit<TextInput, "placeholder"> &
      TextValue & {
        /** `hidden` removes the editor's system background so the element's own background shows through, like SwiftUI's `scrollContentBackground(.hidden)`. */
        scrollcontentbackground?: "hidden" | "visible";
      };
    /** A `Toggle`: an on-off control, drawn as a switch, a checkbox, or a button. */
    toggle: Modifiers & {
      /** Whether the toggle is on. Use `bind:checked` with the `Toggle` component to bind it. */
      checked?: boolean;
      /** The toggle style: `automatic`, `switch`, `button`, or `checkbox`. `switch` always draws a switch, and `button` draws a button that stays highlighted while it's on. */
      variant?: "automatic" | "switch" | "button" | "checkbox";
      /** Runs when the user turns the toggle on or off, with the new `checked` value. */
      onchange?: (checked: boolean) => void;
    };
    /** A `Form`: a screen with the grouped look of the Settings app. */
    formview: Modifiers;
    /** A `Section`: groups rows under an optional `header` and `footer`, in a `formview` or a `list`. */
    sectionview: Modifiers &
      RowEdits & {
        /** The header shown above the rows. A `header` child can replace it with custom content. */
        header?: string;
        /** The footer shown below the rows. A `footer` child can replace it with custom content. */
        footer?: string;
        /** A letter for this section in the list's section index, on iOS 26 and later. */
        indexlabel?: string;
      };
    /** The background of its parent element, drawn behind the parent at its size. The parent's opacity and transforms apply to it too, but its clip shape, border, and shadow don't. */
    background: {
      /** Where the background sits, such as `center` (the default) or a corner such as `bottomTrailing`. */
      alignment?: LayerAlignment;
    };
    /** The overlay of its parent element, drawn in front of the parent at its size. The parent's opacity and transforms apply to it too, but its clip shape, border, and shadow don't. */
    overlay: {
      /** Where the overlay sits, such as `center` (the default) or a corner such as `bottomTrailing`. */
      alignment?: LayerAlignment;
    };
    /** The mask of its parent element: the parent is masked by this element's content. */
    maskview: {
      /** Where the mask sits relative to the parent, such as `center` or `bottom`. */
      alignment?: LayerAlignment;
    };
    /** A `GlassEffectContainer`: renders the Liquid Glass of its children together on iOS 26 and later. */
    glasseffectcontainer: Modifiers & {
      /** The distance in points at which nearby glass shapes blend into one. */
      spacing?: number;
    };
    /** A `.safeAreaInset`: pins its content to one edge of its parent and insets the rest of the parent's content to make room. */
    safeareainset: {
      /** The edge of the parent to pin the content to: `top`, `bottom` (the default), `leading`, or `trailing`. */
      edge?: Edge;
      /** The alignment of the content along the edge. */
      alignment?: HorizontalAlignment | VerticalAlignment;
      /** The space in points between the content and the rest of the parent's content. */
      spacing?: number;
    };
    /** A `Picker`: lets the user choose one option, or several with `multiple`, from its `choice` children. */
    picker: Modifiers &
      (
        | {
            /** Leave it out, or set it to `false`, to let the user choose one option. */
            multiple?: false;
            /** The label of the picker, shown next to the picked value. Use a `label` child for a custom label. */
            label?: string;
            /** The `value` of the selected `choice`. */
            value?: string | number;
            /** The picker style: `automatic`, `menu`, `segmented`, `wheel`, `inline`, or `navigation`. `navigation` opens the options on their own screen, so the picker needs to be inside a `navstack`. */
            variant?:
              | "automatic"
              | "menu"
              | "segmented"
              | "wheel"
              | "inline"
              | "navigation";
            /** Runs when the user picks an option, with the option's `value`. */
            onchange?: (value: string | number) => void;
          }
        | {
            /** Set it to `true` to let the user choose several options. */
            multiple: true;
            /** The label of the picker, shown next to the picked values. Use a `label` child for a custom label. */
            label?: string;
            /** The `value`s of the selected `choice`s, in the order of the choices. */
            value?: Array<string | number>;
            /** The picker style for several options: `inline`, `menu`, or `navigation`. */
            variant?: "inline" | "menu" | "navigation";
            /** Runs when the selection changes, with the new array of values. */
            onchange?: (value: Array<string | number>) => void;
          }
      );
    /** One option of a `picker`: its text is the title, and its `value` is what the picker's `onchange` receives. */
    choice: {
      /** The value that the picker's `onchange` receives when this option is picked. */
      value: string | number;
      /** The SF Symbol shown beside the option's title. */
      symbol?: string;
    };
    /** A `Slider`: lets the user pick a number between `min` and `max`. */
    slider: Modifiers & {
      /** The current value of the slider. */
      value?: number;
      /** The lowest value. Defaults to 0. */
      min?: number;
      /** The highest value. Defaults to 1. */
      max?: number;
      /** Snaps the value to multiples of this number. */
      step?: number;
      /** Runs while the user drags the slider, with the new value. */
      oninput?: (value: number) => void;
      /** Runs when the user lets go of the slider, with the final value. */
      onchange?: (value: number) => void;
    };
    /** A `Stepper`: changes a number by `step` with plus and minus buttons. */
    stepper: Modifiers & {
      /** The current value of the stepper. */
      value?: number;
      /** The lowest value. Without it, there's no lower limit. */
      min?: number;
      /** The highest value. Without it, there's no upper limit. */
      max?: number;
      /** The amount that each press adds or subtracts. Defaults to 1. */
      step?: number;
      /** Runs when the value changes, with the new value. */
      onchange?: (value: number) => void;
    };
    /** A `DatePicker`: lets the user pick a date, a time, or both. */
    datepicker: Modifiers & {
      /** The date to show, as a `Date` or an ISO 8601 string. */
      value?: Date | string;
      /** The earliest date the user can pick, as a `Date` or an ISO 8601 string. */
      min?: Date | string;
      /** The latest date the user can pick, as a `Date` or an ISO 8601 string. */
      max?: Date | string;
      /** Which parts the user picks: `date`, `time`, or `datetime`. Defaults to `datetime`. */
      components?: "date" | "time" | "datetime";
      /** The picker style: `automatic`, `compact`, `graphical`, or `wheel`. */
      variant?: "automatic" | "compact" | "graphical" | "wheel";
      /** Runs when the user picks a date, with a `Date`. */
      onchange?: (value: Date) => void;
    };
    /** A `ProgressView`: shows a bar filled to `value` out of `total`, or a spinner when there's no `value`. */
    progressview: Modifiers & {
      /** The progress so far, up to `total`. Leave it out for a spinner. */
      value?: number;
      /** The value that means complete. Defaults to 1. */
      total?: number;
    };
    /** A `MultiDatePicker`: a calendar where the user taps days on and off. */
    multidatepicker: Modifiers & {
      /** The picked days, as `YYYY-MM-DD` strings. These don't depend on the time zone. */
      value?: Array<string>;
      /** The earliest day the user can pick, as a `Date` or an ISO 8601 string. */
      min?: Date | string;
      /** The latest day the user can pick, as a `Date` or an ISO 8601 string. */
      max?: Date | string;
      /** Runs when the user taps a day on or off, with the new array of days. */
      onchange?: (value: Array<string>) => void;
    };
    /** A `ColorPicker`: lets the user pick a color. */
    colorpicker: Modifiers & {
      /** The starting color, as any color value. Defaults to black. */
      value?: string;
      /** Whether the user can change the opacity. Defaults to `true`. */
      supportsopacity?: boolean;
      /** Runs when the user picks a color, with a hex string such as `#FF9500`, or `#FF950080` when the color is partly transparent. */
      onchange?: (value: `#${string}`) => void;
    };
    /** A `Gauge`: shows a value between `min` and `max` on a circular or linear scale. */
    gauge: Modifiers & {
      /** The current value, kept between `min` and `max`. */
      value?: number;
      /** The lowest value. Defaults to 0. */
      min?: number;
      /** The highest value. Defaults to 1. */
      max?: number;
      /** Short text shown for the current value. */
      current?: string;
      /** Short text shown at the low end of the gauge. */
      minlabel?: string;
      /** Short text shown at the high end of the gauge. */
      maxlabel?: string;
      /** The gauge style: `automatic`, `circular`, `circularCapacity`, `linear`, or `linearCapacity`. */
      variant?:
        | "automatic"
        | "circular"
        | "circularCapacity"
        | "linear"
        | "linearCapacity";
    };
    /** A `LabeledContent`: shows a title with a value on the trailing side, like a row in Settings. */
    labeledcontent: Modifiers & {
      /** The label on the leading side. Use a `label` child for a custom label. */
      title?: string;
      /** The value on the trailing side. Without it, the children are the content. */
      value?: string | number;
    };
    /** A `ContentUnavailableView`: an empty state with a symbol, a title, a description, and optional action buttons. */
    contentunavailableview: Modifiers & {
      /** The title of the empty state. */
      title?: string;
      /** The SF Symbol shown above the title. */
      symbol?: string;
      /** Explanatory text shown below the title. */
      description?: string;
      /** `search` shows the system's "No Results" message, and mentions `query` when it's set. */
      variant?: "automatic" | "search";
      /** The search text to mention in the `search` message. */
      query?: string;
    };
    /** A `Menu`: opens a menu of its children when tapped. */
    menuview: Modifiers & {
      /** The label of the menu, shown with `symbol`. Use a `label` child for a custom label. */
      title?: string;
      /** The SF Symbol shown beside the title. */
      symbol?: string;
      /** The menu button style: `automatic`, `button`, or `borderlessButton`. */
      variant?: "automatic" | "button" | "borderlessButton";
      /** The order of the menu items: `automatic`, `fixed`, or `priority`. */
      order?: "automatic" | "fixed" | "priority";
      /** Runs when the menu is tapped, instead of opening it. A long press still opens the menu. */
      onprimaryaction?: () => void;
    };
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
  var __svelteDispatch: (
    id: number,
    type: string,
    payload: unknown,
    request?: number,
  ) => void;
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
    onEnd: (
      failure: { message: string; code?: number; name?: string } | null,
    ) => void,
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
