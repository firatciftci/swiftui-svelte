import type { Attributes, Expression } from "./runtime.ts";
import type { Lookup, Rgba } from "./values.ts";
import { SYSTEM_COLORS } from "./system-colors.ts";
import {
  compact,
  fixedPixels,
  numberOf,
  parseColor,
  pixels,
  quantityOf,
  splitTopLevel,
  substitute,
  times,
  toHex,
  Unsupported,
} from "./values.ts";

export type Declaration = {
  property: string;
  value: string;
  important: boolean;
};
export type Patch = {
  attrs: Attributes;
  only?: Array<string>;
  when?: Array<string>;
};
export type Mapping = { patches: Array<Patch>; problems: Array<string> };

type Context = {
  candidate: string;
  lookup: Lookup;
  fontSize: Expression;
  fonts: ReadonlyMap<string, string>;
  corners: Record<string, Expression>;
};

const VERTICAL = ["vstack", "lazyvstack"];
const HORIZONTAL = ["hstack", "lazyhstack"];
const STACKS = [...VERTICAL, ...HORIZONTAL];

const WEIGHTS: Record<string, string> = {
  "100": "ultraLight",
  "200": "thin",
  "300": "light",
  "400": "regular",
  "500": "medium",
  "600": "semibold",
  "700": "bold",
  "800": "heavy",
  "900": "black",
};

const DESIGNS: Record<string, string> = {
  serif: "serif",
  "ui-serif": "serif",
  monospace: "monospaced",
  "ui-monospace": "monospaced",
  "sans-serif": "default",
  "ui-sans-serif": "default",
  "system-ui": "default",
  "-apple-system": "default",
  BlinkMacSystemFont: "default",
};

const BLEND_MODES = new Set([
  "normal",
  "multiply",
  "screen",
  "overlay",
  "darken",
  "lighten",
  "color-dodge",
  "color-burn",
  "soft-light",
  "hard-light",
  "difference",
  "exclusion",
  "hue",
  "saturation",
  "color",
  "luminosity",
  "plus-lighter",
  "plus-darker",
]);

const IGNORED = new Set([
  "accent-color",
  "animation-timing-function",
  "appearance",
  "box-sizing",
  "caret-color",
  "color-scheme",
  "content-visibility",
  "contain",
  "cursor",
  "font-feature-settings",
  "font-smoothing",
  "font-variation-settings",
  "forced-color-adjust",
  "hyphens",
  "isolation",
  "outline",
  "outline-color",
  "outline-offset",
  "outline-style",
  "outline-width",
  "overflow-wrap",
  "overscroll-behavior",
  "resize",
  "scroll-behavior",
  "scrollbar-width",
  "tab-size",
  "text-rendering",
  "text-size-adjust",
  "touch-action",
  "transition-behavior",
  "transition-property",
  "transition-timing-function",
  "transform-origin",
  "will-change",
  "word-break",
]);

const CORNERS: Record<string, string> = {
  "border-top-left-radius": "topleading",
  "border-top-right-radius": "toptrailing",
  "border-bottom-left-radius": "bottomleading",
  "border-bottom-right-radius": "bottomtrailing",
};

const PADDING_EDGES: Record<string, Array<string>> = {
  padding: ["top", "leading", "bottom", "trailing"],
  "padding-inline": ["leading", "trailing"],
  "padding-block": ["top", "bottom"],
  "padding-top": ["top"],
  "padding-right": ["trailing"],
  "padding-bottom": ["bottom"],
  "padding-left": ["leading"],
  "padding-inline-start": ["leading"],
  "padding-inline-end": ["trailing"],
};

const POSITIONING = new Set([
  "bottom",
  "inset",
  "inset-block",
  "inset-inline",
  "left",
  "right",
  "top",
  "position",
]);

const MARGIN_EDGES: Record<string, Array<string>> = {
  margin: ["top", "leading", "bottom", "trailing"],
  "margin-inline": ["leading", "trailing"],
  "margin-block": ["top", "bottom"],
  "margin-top": ["top"],
  "margin-right": ["trailing"],
  "margin-bottom": ["bottom"],
  "margin-left": ["leading"],
  "margin-inline-start": ["leading"],
  "margin-inline-end": ["trailing"],
  "margin-block-start": ["top"],
  "margin-block-end": ["bottom"],
};

const BORDER_EDGES: Record<string, Array<string>> = {
  "border-width": ["top", "leading", "bottom", "trailing"],
  "border-top-width": ["top"],
  "border-right-width": ["trailing"],
  "border-bottom-width": ["bottom"],
  "border-left-width": ["leading"],
  "border-inline-width": ["leading", "trailing"],
  "border-block-width": ["top", "bottom"],
  "border-inline-start-width": ["leading"],
  "border-inline-end-width": ["trailing"],
  "border-block-start-width": ["top"],
  "border-block-end-width": ["bottom"],
};

const ALIGNMENTS: Record<string, { horizontal: string; vertical: string }> = {
  start: { horizontal: "leading", vertical: "top" },
  "flex-start": { horizontal: "leading", vertical: "top" },
  center: { horizontal: "center", vertical: "center" },
  end: { horizontal: "trailing", vertical: "bottom" },
  "flex-end": { horizontal: "trailing", vertical: "bottom" },
};

function stack(
  axis: "horizontal" | "vertical",
  only?: Array<string>,
): Array<Patch> {
  return [{ attrs: { css: true, axis }, only }];
}

const ALIGN_CONTENT = new Set([
  "start",
  "end",
  "center",
  "stretch",
  "flex-start",
  "flex-end",
]);

const ALIGN_SELF: Record<string, string> = {
  start: "start",
  "flex-start": "start",
  center: "center",
  end: "end",
  "flex-end": "end",
  stretch: "stretch",
};

function reason(property: string): string {
  if (POSITIONING.has(property))
    return "Absolute and fixed positioning don't exist in SwiftUI. Use zstack with an alignment, an overlay, or the offset and position attributes";
  if (
    property.startsWith("grid") ||
    property.startsWith("justify-") ||
    property.startsWith("place-")
  )
    return "CSS grid and item distribution don't exist in SwiftUI. Use a grid, lazyvgrid, or lazyhgrid element, or a spacer";
  if (property === "content") return "Pseudo-elements don't exist in SwiftUI";
  if (property.startsWith("background"))
    return "Background images and positions don't exist in SwiftUI. Use an imageview or asyncimage element";
  if (property.startsWith("animation"))
    return "CSS keyframe animations don't exist in SwiftUI. Use the animation attribute or a symbol effect";
  return `${property} has no native equivalent`;
}

function latestDeclarations(
  declarations: Array<Declaration>,
): Array<Declaration> {
  return declarations.filter(
    (declaration, index) =>
      declarations.findLastIndex(
        (other) => other.property === declaration.property,
      ) === index,
  );
}

export function mapCandidate(
  candidate: string,
  declarations: Array<Declaration>,
  globals: Lookup,
  fonts: ReadonlyMap<string, string>,
): Mapping {
  const locals = new Map<string, string>();
  for (const declaration of declarations) {
    if (declaration.property.startsWith("--"))
      locals.set(declaration.property, declaration.value);
  }
  const lookup: Lookup = (name) => locals.get(name) ?? globals(name);
  const fontSize = fontSizeOf(declarations, lookup);
  const context: Context = { candidate, lookup, fontSize, fonts, corners: {} };
  const mapping: Mapping = { patches: [], problems: [] };
  for (const declaration of latestDeclarations(declarations)) {
    try {
      const patches = mapDeclaration(declaration, context);
      if (patches == null) mapping.problems.push(reason(declaration.property));
      else mapping.patches.push(...patches);
    } catch (error) {
      if (!(error instanceof Unsupported)) throw error;
      mapping.problems.push(error.message);
    }
  }
  if (Object.keys(context.corners).length > 0)
    mapping.patches.push({ attrs: { clipshape: context.corners } });
  if (mapping.patches.length === 0 && mapping.problems.length === 0)
    mapping.problems.push("This utility has no native equivalent");
  return mapping;
}

function fontSizeOf(
  declarations: Array<Declaration>,
  lookup: Lookup,
): Expression {
  const size = declarations.find(
    (declaration) => declaration.property === "font-size",
  );
  return size == null ? 16 : pixels(substitute(size.value, lookup), 16);
}

function resolved(value: string, { lookup }: Context): string {
  return substitute(value, lookup);
}

function points(value: string, context: Context): Expression {
  return pixels(substitute(value, context.lookup), context.fontSize);
}

const PLATFORM_COLOR = /^platformColor\((.+)\)$/;

function systemColorOf(name: string): string {
  if (!SYSTEM_COLORS.has(name))
    throw new Unsupported(
      `platformColor(${name}) isn't a system color this library supports`,
    );
  return name;
}

function colorOf(value: string, context: Context): string | null {
  const platform = PLATFORM_COLOR.exec(
    substitute(value, context.lookup).trim(),
  );
  if (platform != null) return systemColorOf(platform[1]?.trim() ?? "");
  const parsed = parseColor(resolved(value, context));
  return parsed === "currentcolor" ? null : toHex(parsed);
}

function spread(value: string): Array<string> {
  return splitTopLevel(value.trim(), /\s/);
}

type Handler = (
  value: string,
  context: Context,
  raw: string,
) => Array<Patch> | null;

const HANDLERS = new Map<string, Handler>([
  [
    "border-radius",
    (value, context) => {
      return [{ attrs: { radius: points(value, context) } }];
    },
  ],
  [
    "display",
    (_value, _context, raw) => {
      if (raw === "none") return [{ attrs: { hidden: true } }];
      if (["flex", "inline-flex"].includes(raw))
        return stack("horizontal", STACKS);
      if (["grid", "inline-grid"].includes(raw))
        return stack("vertical", STACKS);
      return ["block", "inline", "inline-block", "contents"].includes(raw)
        ? [{ attrs: {} }]
        : null;
    },
  ],
  [
    "visibility",
    (_value, _context, raw) => {
      if (raw === "hidden") return [{ attrs: { hidden: true } }];
      return raw === "visible" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "position",
    (_value, _context, raw) => {
      return raw === "relative" || raw === "static" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "overflow",
    (_value, _context, raw) => {
      return raw === "hidden" ? [{ attrs: { clipshape: "rectangle" } }] : null;
    },
  ],
  [
    "width",
    (_value, context, raw) => {
      return sizing("width", raw, context);
    },
  ],
  [
    "height",
    (_value, context, raw) => {
      return sizing("height", raw, context);
    },
  ],
  [
    "min-width",
    (_value, context, raw) => {
      return sizing("min-width", raw, context);
    },
  ],
  [
    "min-height",
    (_value, context, raw) => {
      return sizing("min-height", raw, context);
    },
  ],
  [
    "max-width",
    (_value, context, raw) => {
      return sizing("max-width", raw, context);
    },
  ],
  [
    "max-height",
    (_value, context, raw) => {
      return sizing("max-height", raw, context);
    },
  ],
  [
    "aspect-ratio",
    (_value, _context, raw) => {
      const [first = "1", second] = raw.split("/").map((part) => part.trim());
      return [
        {
          attrs: {
            aspectratio:
              second == null
                ? numberOf(first)
                : numberOf(first) / numberOf(second),
          },
        },
      ];
    },
  ],
  [
    "flex",
    (value, context) => {
      if (
        !["1 1 0%", "1 1 0px", "1"].includes(
          resolved(value, context).replaceAll(/\s+/g, " "),
        )
      )
        return null;
      return [
        { attrs: { maxwidth: "infinity" }, only: HORIZONTAL },
        { attrs: { maxheight: "infinity" }, only: VERTICAL },
      ];
    },
  ],
  [
    "flex-direction",
    (_value, _context, raw) => {
      if (raw === "column") return stack("vertical", VERTICAL);
      return raw === "row" ? stack("horizontal", HORIZONTAL) : null;
    },
  ],
  [
    "grid-template-columns",
    (_value, _context, raw) => {
      return compact(raw).replaceAll(" ", "") === "repeat(1,minmax(0,1fr))"
        ? stack("vertical", VERTICAL)
        : null;
    },
  ],
  [
    "grid-auto-flow",
    (_value, _context, raw) => {
      if (raw === "column") return stack("horizontal", HORIZONTAL);
      return raw === "row" ? stack("vertical", VERTICAL) : null;
    },
  ],
  [
    "align-content",
    (_value, _context, raw) => {
      return ALIGN_CONTENT.has(raw) ? [{ attrs: {} }] : null;
    },
  ],
  [
    "table-layout",
    (_value, _context, raw) => {
      return raw === "fixed" || raw === "auto" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "border-collapse",
    (_value, _context, raw) => {
      return raw === "collapse" || raw === "separate" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "justify-content",
    (_value, _context, raw) => {
      const sides: Record<string, string> = {
        start: "start",
        "flex-start": "start",
        center: "center",
        end: "end",
        "flex-end": "end",
      };
      const side = sides[raw];
      if (side == null) return null;
      const vertical =
        side === "start" ? "top" : side === "end" ? "bottom" : "center";
      const horizontal =
        side === "start" ? "leading" : side === "end" ? "trailing" : "center";
      return [
        { attrs: { framealignment: vertical }, only: VERTICAL },
        { attrs: { framealignment: horizontal }, only: HORIZONTAL },
      ];
    },
  ],
  [
    "justify-items",
    (_value, _context, raw) => {
      const entry = ALIGNMENTS[raw];
      return entry == null
        ? null
        : [{ attrs: { alignment: entry.horizontal }, only: VERTICAL }];
    },
  ],
  [
    "align-self",
    (_value, _context, raw) => {
      const side = ALIGN_SELF[raw];
      return side == null ? null : [{ attrs: { selfalign: side } }];
    },
  ],
  [
    "justify-self",
    (_value, _context, raw) => {
      const side = ALIGN_SELF[raw];
      return side == null ? null : [{ attrs: { selfalign: side } }];
    },
  ],
  [
    "container-type",
    (_value, _context, raw) => {
      return raw === "inline-size" ? [{ attrs: { container: "" } }] : null;
    },
  ],
  [
    "container-name",
    (_value, _context, raw) => {
      return [{ attrs: { container: raw } }];
    },
  ],
  [
    "text-wrap",
    (_value, _context, raw) => {
      if (raw === "balance")
        return [{ attrs: { balanced: true }, only: ["txt"] }];
      if (["wrap", "pretty", "stable"].includes(raw))
        return [{ attrs: {}, only: ["txt"] }];
      if (raw === "nowrap") return [{ attrs: { lines: 1 }, only: ["txt"] }];
      return null;
    },
  ],
  [
    "flex-wrap",
    (_value, _context, raw) => {
      if (raw === "wrap") return [{ attrs: {}, only: ["flowstack"] }];
      return raw === "nowrap" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "flex-shrink",
    (_value, _context, raw) => {
      if (raw !== "0") return null;
      return [
        { attrs: { fixedsize: "horizontal" }, only: HORIZONTAL },
        { attrs: { fixedsize: "vertical" }, only: VERTICAL },
      ];
    },
  ],
  [
    "flex-grow",
    (_value, _context, raw) => {
      return raw === "0" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "align-items",
    (_value, _context, raw) => {
      return alignItems(raw);
    },
  ],
  [
    "gap",
    (value, context) => {
      return [{ attrs: { spacing: points(value, context) }, only: STACKS }];
    },
  ],
  [
    "row-gap",
    (value, context) => {
      return [{ attrs: { spacing: points(value, context) }, only: VERTICAL }];
    },
  ],
  [
    "column-gap",
    (value, context) => {
      return [{ attrs: { spacing: points(value, context) }, only: HORIZONTAL }];
    },
  ],
  [
    "z-index",
    (_value, _context, raw) => {
      return [{ attrs: { zindex: numberOf(raw) } }];
    },
  ],
  [
    "opacity",
    (_value, _context, raw) => {
      return [{ attrs: { opacity: numberOf(raw) } }];
    },
  ],
  [
    "box-shadow",
    (value, context) => {
      return boxShadow(value, context);
    },
  ],
  [
    "filter",
    (value, context) => {
      return filters(value, context);
    },
  ],
  [
    "color",
    (value, context) => {
      return [{ attrs: { color: colorOf(value, context) } }];
    },
  ],
  [
    "background-color",
    (value, context) => {
      return [{ attrs: { background: colorOf(value, context) } }];
    },
  ],
  [
    "background-image",
    (_value, context, raw) => {
      return gradient(raw, context);
    },
  ],
  [
    "font-size",
    (value, context) => {
      return [{ attrs: { size: points(value, context) } }];
    },
  ],
  [
    "line-height",
    (value, context, raw) => {
      if (raw === "normal") return [{ attrs: { linebox: null } }];
      const quantity = quantityOf(resolved(value, context), context.fontSize);
      if (quantity.unit === "" && typeof quantity.value === "number")
        return [
          { attrs: { linebox: times(quantity.value, context.fontSize) } },
        ];
      return [{ attrs: { linebox: points(value, context) } }];
    },
  ],
  [
    "font-weight",
    (value, context, raw) => {
      const numeric = resolved(value, context);
      const weight =
        numeric === "normal" ? "400" : numeric === "bold" ? "700" : numeric;
      const name = WEIGHTS[weight];
      if (name == null)
        throw new Unsupported(`font-weight: ${raw} has no native equivalent`);
      return [{ attrs: { weight: name } }];
    },
  ],
  [
    "font-family",
    (_value, context, raw) => {
      return [fontFamily(raw, context)];
    },
  ],
  [
    "font-style",
    (_value, _context, raw) => {
      return [{ attrs: { italic: raw === "italic" } }];
    },
  ],
  [
    "font-variant-numeric",
    (_value, _context, raw) => {
      if (!raw.includes("tabular-nums")) return [{ attrs: {} }];
      return [{ attrs: { monospaceddigit: true }, only: ["txt"] }];
    },
  ],
  [
    "letter-spacing",
    (value, context) => {
      return [{ attrs: { tracking: points(value, context) }, only: ["txt"] }];
    },
  ],
  [
    "text-align",
    (_value, _context, raw) => {
      return textAlign(raw);
    },
  ],
  [
    "text-decoration-line",
    (_value, _context, raw) => {
      return [
        {
          attrs: {
            underline: raw.includes("underline"),
            strikethrough: raw.includes("line-through"),
          },
          only: ["txt"],
        },
      ];
    },
  ],
  [
    "text-decoration-color",
    (value, context) => {
      return [
        { attrs: { underlinecolor: colorOf(value, context) }, only: ["txt"] },
      ];
    },
  ],
  [
    "text-decoration-style",
    (_value, _context, raw) => {
      return ["solid", "dotted", "dashed"].includes(raw)
        ? [{ attrs: { underlinestyle: raw }, only: ["txt"] }]
        : null;
    },
  ],
  [
    "text-overflow",
    (_value, _context, raw) => {
      return raw === "ellipsis"
        ? [{ attrs: { truncation: "tail" }, only: ["txt"] }]
        : null;
    },
  ],
  [
    "white-space",
    (_value, _context, raw) => {
      if (raw === "nowrap") return [{ attrs: { lines: 1 }, only: ["txt"] }];
      if (raw === "pre" || raw === "pre-line")
        return [{ attrs: { whitespace: raw }, only: ["txt"] }];
      return raw === "normal"
        ? [{ attrs: { whitespace: "normal" }, only: ["txt"] }]
        : null;
    },
  ],
  [
    "-webkit-line-clamp",
    (_value, _context, raw) => {
      return [{ attrs: { lines: numberOf(raw) }, only: ["txt"] }];
    },
  ],
  [
    "user-select",
    (_value, _context, raw) => {
      if (raw === "none")
        return [{ attrs: { selectable: false }, only: ["txt"] }];
      return raw === "text" || raw === "all"
        ? [{ attrs: { selectable: true }, only: ["txt"] }]
        : null;
    },
  ],
  [
    "pointer-events",
    (_value, _context, raw) => {
      if (raw === "none") return [{ attrs: { allowshittesting: false } }];
      return raw === "auto" ? [{ attrs: {} }] : null;
    },
  ],
  [
    "mix-blend-mode",
    (_value, _context, raw) => {
      return BLEND_MODES.has(raw) ? [{ attrs: { blendmode: raw } }] : null;
    },
  ],
  [
    "scale",
    (value, context) => {
      return scale(resolved(value, context));
    },
  ],
  [
    "rotate",
    (_value, _context, raw) => {
      const match = /^(-?[\d.]+)deg$/.exec(raw);
      return match?.[1] == null
        ? null
        : [{ attrs: { rotation: Number(match[1]) } }];
    },
  ],
  [
    "translate",
    (value, context) => {
      const [x = "0", y = "0"] = spread(resolved(value, context));
      return [
        {
          attrs: {
            offset: {
              x: pixels(x, context.fontSize),
              y: pixels(y, context.fontSize),
            },
          },
        },
      ];
    },
  ],
  [
    "transition-duration",
    (_value, context, raw) => {
      return [{ attrs: { $duration: milliseconds(resolved(raw, context)) } }];
    },
  ],
  [
    "object-fit",
    (_value, _context, raw) => {
      return objectFit(raw);
    },
  ],
  ["tint", (value, context) => [{ attrs: { tint: colorOf(value, context) } }]],
  [
    "elevation",
    (value, context) => [
      {
        attrs: { elevation: numberOf(resolved(value, context)) },
        when: ["platform:android"],
      },
    ],
  ],
  [
    "ripple-color",
    (value, context) => [
      {
        attrs: { ripple: { color: colorOf(value, context) } },
        when: ["platform:android"],
      },
    ],
  ],
  [
    "ripple-layer",
    (value) => [
      {
        attrs: { ripple: { layer: value.trim() } },
        when: ["platform:android"],
      },
    ],
  ],
  [
    "corner-shape",
    (_value, _context, raw) => {
      if (raw === "squircle") return [{ attrs: { cornerstyle: "continuous" } }];
      if (raw === "round") return [{ attrs: { cornerstyle: "circular" } }];
      return null;
    },
  ],
]);

function isBoxProperty(property: string): boolean {
  return (
    Object.hasOwn(MARGIN_EDGES, property) ||
    Object.hasOwn(BORDER_EDGES, property) ||
    /^border(?:-[a-z-]+)?-(?:style|color)$/.test(property)
  );
}

function boxPatches(
  property: string,
  value: string,
  raw: string,
  context: Context,
): Array<Patch> | null {
  if (Object.hasOwn(MARGIN_EDGES, property)) {
    if (/^-?space-[xy]-/.test(context.candidate))
      return spacing(property, value, context);
    const amount = raw === "auto" ? "auto" : points(value, context);
    const edges = Object.fromEntries(
      (MARGIN_EDGES[property] ?? []).map((edge) => [edge, amount]),
    );
    return [{ attrs: { margin: edges } }];
  }
  if (Object.hasOwn(BORDER_EDGES, property)) {
    const amount = points(value, context);
    const edges = Object.fromEntries(
      (BORDER_EDGES[property] ?? []).map((edge) => [edge, amount]),
    );
    return [{ attrs: { $borderWidth: edges } }];
  }
  if (property.endsWith("-style"))
    return resolved(value, context) === "solid" ? [{ attrs: {} }] : null;
  return [{ attrs: { $borderColor: colorOf(value, context) } }];
}

function mapDeclaration(
  declaration: Declaration,
  context: Context,
): Array<Patch> | null {
  const { property, value } = declaration;
  const raw = value.trim();
  if (property.startsWith("--"))
    return customProperty(property, value, context);
  if (
    IGNORED.has(property) ||
    property.startsWith("-webkit-") ||
    property.startsWith("-moz-")
  )
    return [{ attrs: {} }];
  if (
    property === "transform" &&
    (raw === "none" || raw.includes("translate3d"))
  )
    return [{ attrs: {} }];
  if (Object.hasOwn(PADDING_EDGES, property)) {
    const amount = points(value, context);
    const edges = Object.fromEntries(
      (PADDING_EDGES[property] ?? []).map((edge) => [edge, amount]),
    );
    return [{ attrs: { padding: edges } }];
  }
  if (isBoxProperty(property)) return boxPatches(property, value, raw, context);
  if (Object.hasOwn(CORNERS, property)) {
    const corner = CORNERS[property];
    if (corner != null) context.corners[corner] = points(value, context);
    return [{ attrs: {} }];
  }
  return HANDLERS.get(property)?.(value, context, raw) ?? null;
}

function customProperty(
  property: string,
  value: string,
  context: Context,
): Array<Patch> {
  const raw = value.trim();
  switch (property) {
    case "--tw-gradient-from":
    case "--tw-gradient-via":
    case "--tw-gradient-to": {
      return [
        {
          attrs: {
            $stop: { [property.slice(14)]: { color: colorOf(value, context) } },
          },
        },
      ];
    }
    case "--tw-gradient-from-position":
    case "--tw-gradient-via-position":
    case "--tw-gradient-to-position": {
      return [
        {
          attrs: {
            $stop: {
              [property.slice(14, -9)]: {
                location: numberOf(resolved(raw, context)),
              },
            },
          },
        },
      ];
    }
    case "--tw-ring-color": {
      return [{ attrs: { $ringColor: colorOf(value, context) } }];
    }
    case "--tw-shadow-color": {
      return [{ attrs: { $shadowColor: colorOf(value, context) } }];
    }
    default: {
      return [];
    }
  }
}

function spacing(
  property: string,
  value: string,
  context: Context,
): Array<Patch> | null {
  if (!/^-?space-[xy]-/.test(context.candidate)) return null;
  if (property === "margin-block-end")
    return [{ attrs: { spacing: points(value, context) }, only: VERTICAL }];
  if (property === "margin-inline-end")
    return [{ attrs: { spacing: points(value, context) }, only: HORIZONTAL }];
  return [{ attrs: {} }];
}

function alignItems(raw: string): Array<Patch> | null {
  const entry = ALIGNMENTS[raw];
  if (entry == null) return null;
  return [
    { attrs: { alignment: entry.horizontal }, only: VERTICAL },
    { attrs: { alignment: entry.vertical }, only: HORIZONTAL },
  ];
}

function textAlign(raw: string): Array<Patch> {
  const alignments: Record<string, string> = {
    left: "leading",
    start: "leading",
    center: "center",
    right: "trailing",
    end: "trailing",
  };
  const alignment = alignments[raw];
  if (alignment == null)
    throw new Unsupported(`text-align: ${raw} has no native equivalent`);
  return [{ attrs: { alignment }, only: ["txt"] }];
}

function objectFit(raw: string): Array<Patch> | null {
  const fits: Record<string, string> = {
    cover: "fill",
    contain: "fit",
    fill: "stretch",
  };
  const fit = fits[raw];
  return fit == null
    ? null
    : [{ attrs: { fit }, only: ["imageview", "asyncimage"] }];
}

const SCREEN_SAFE =
  /^calc\(100[dsl]?vh - \(env\(safe-area-inset-top\) \+ env\(safe-area-inset-bottom\)\)\)$/;

function sizing(property: string, raw: string, context: Context): Array<Patch> {
  const axis = property.endsWith("width") ? "width" : "height";
  const prefix = property.startsWith("min-")
    ? "min"
    : property.startsWith("max-")
      ? "max"
      : "";
  const key = prefix === "" ? axis : `${prefix}${axis}`;
  if (raw === "auto" && prefix === "") return [{ attrs: { [key]: null } }];
  const value = compact(raw);
  if (prefix === "max" && (raw === "none" || value === "100%"))
    return [{ attrs: { [key]: null } }];
  if (
    value === "100%" ||
    /^100[dsl]?v[hw]$/.test(value) ||
    SCREEN_SAFE.test(value)
  )
    return [{ attrs: { [key]: "infinity", boxsizing: "border-box" } }];
  const quantity = quantityOf(resolved(raw, context), context.fontSize);
  if (quantity.unit === "%")
    throw new Unsupported(`${property}: ${raw} isn't a fixed size`);
  const length = quantity.value;
  return [
    {
      attrs: {
        [key]:
          typeof length === "number" && !Number.isFinite(length)
            ? 9999
            : length,
        boxsizing: "border-box",
      },
    },
  ];
}

type Layer = {
  x: number;
  y: number;
  blur: number;
  spread: number;
  color: Rgba | "currentcolor";
};

function layers(
  value: string,
  context: Context,
): Array<Layer & { inset: boolean }> {
  const parsed = splitTopLevel(resolved(value, context), /,/).map((layer) => {
    const parts = splitTopLevel(layer.trim(), /\s/);
    const lengths: Array<number> = [];
    let layerColor: Rgba | "currentcolor" = "currentcolor";
    let isInset = false;
    for (const part of parts) {
      if (part === "inset") isInset = true;
      else if (/^(?:-?[\d.]|(?:calc|min|max|clamp|round)\()/.test(part))
        lengths.push(fixedPixels(part, context.fontSize));
      else layerColor = parseColor(part);
    }
    const [x = 0, y = 0, blur = 0, spreadLength = 0] = lengths;
    return {
      x,
      y,
      blur,
      spread: spreadLength,
      color: layerColor,
      inset: isInset,
    };
  });
  return parsed.filter(
    (layer) =>
      layer.color === "currentcolor" ||
      layer.color.a > 0 ||
      layer.x !== 0 ||
      layer.y !== 0 ||
      layer.blur !== 0 ||
      layer.spread !== 0,
  );
}

function boxShadow(value: string, context: Context): Array<Patch> {
  if (value.trim() === "none") return [{ attrs: { shadow: false } }];
  const all = layers(value, context);
  if (all.some((layer) => layer.inset))
    throw new Unsupported("Inset shadows don't exist in SwiftUI");
  const ring = all.find(
    (layer) =>
      layer.spread > 0 && layer.blur === 0 && layer.x === 0 && layer.y === 0,
  );
  const drop = all
    .filter((layer) => layer !== ring)
    .toSorted((a, b) => b.blur - a.blur)[0];
  const patches: Array<Patch> = [];
  if (ring != null) patches.push({ attrs: { $ringWidth: ring.spread } });
  if (drop != null) patches.push({ attrs: { shadow: shadowOf(drop) } });
  return patches.length > 0 ? patches : [{ attrs: { shadow: false } }];
}

function shadowOf(layer: Layer): {
  color?: string;
  radius: number;
  x: number;
  y: number;
} {
  return {
    color: layer.color === "currentcolor" ? undefined : toHex(layer.color),
    radius: layer.blur,
    x: layer.x,
    y: layer.y,
  };
}

function filters(value: string, context: Context): Array<Patch> {
  const text = resolved(value, context).trim();
  if (text === "none") return [{ attrs: {} }];
  const patches: Array<Patch> = [];
  for (const token of spread(text)) {
    const open = token.indexOf("(");
    const name = open === -1 ? token : token.slice(0, open);
    const argument = open === -1 ? "" : token.slice(open + 1, -1).trim();
    switch (name) {
      case "blur": {
        patches.push({ attrs: { blur: pixels(argument, context.fontSize) } });
        break;
      }
      case "brightness": {
        patches.push({ attrs: { brightness: numberOf(argument) - 1 } });
        break;
      }
      case "drop-shadow": {
        const [layer] = layers(argument, context);
        if (layer != null) patches.push({ attrs: { shadow: shadowOf(layer) } });

        break;
      }
      default: {
        throw new Unsupported(`filter: ${name}() has no native equivalent`);
      }
    }
  }
  return patches.length > 0 ? patches : [{ attrs: {} }];
}

function scale(raw: string): Array<Patch> {
  const [x = "1", y] = spread(raw);
  const horizontal = numberOf(x);
  if (y == null || numberOf(y) === horizontal)
    return [{ attrs: { scale: horizontal } }];
  return [{ attrs: { scale: { x: horizontal, y: numberOf(y) } } }];
}

function milliseconds(raw: string): number {
  const match = /^([\d.]+)(ms|s)$/.exec(raw);
  if (match?.[1] == null)
    throw new Unsupported(`transition-duration: ${raw} isn't supported`);
  return Number(match[1]) * (match[2] === "s" ? 1000 : 1);
}

function gradient(raw: string, context: Context): Array<Patch> | null {
  if (!raw.includes("--tw-gradient-stops")) return null;
  const position = context.lookup("--tw-gradient-position") ?? "to bottom";
  const sides = spread(position).filter((word) =>
    ["top", "bottom", "left", "right"].includes(word),
  );
  const vertical = sides.find((side) => side === "top" || side === "bottom");
  const horizontal = sides.find((side) => side === "left" || side === "right");
  if (!position.trim().startsWith("to ") || sides.length === 0)
    throw new Unsupported(`gradient direction "${position}" isn't supported`);
  const startVertical =
    vertical === "bottom" ? "top" : vertical === "top" ? "bottom" : undefined;
  const startHorizontal =
    horizontal === "right"
      ? "leading"
      : horizontal === "left"
        ? "trailing"
        : undefined;
  const endHorizontal =
    horizontal === "right"
      ? "trailing"
      : horizontal === "left"
        ? "leading"
        : undefined;
  return [
    {
      attrs: {
        $direction: {
          start: point(startVertical, startHorizontal),
          end: point(vertical, endHorizontal),
        },
      },
    },
  ];
}

function point(
  vertical: string | undefined,
  horizontal: string | undefined,
): string {
  if (vertical != null && horizontal != null)
    return `${vertical}${horizontal[0]?.toUpperCase()}${horizontal.slice(1)}`;
  return vertical ?? horizontal ?? "center";
}

function fontFamily(raw: string, context: Context): Patch {
  const [first = "", ...rest] = splitTopLevel(resolved(raw, context), /,/).map(
    (family) => family.trim().replaceAll(/^["']|["']$/g, ""),
  );
  const postScript = context.fonts.get(first);
  if (postScript != null) return { attrs: { fontname: postScript } };
  const design = DESIGNS[first];
  if (design != null) return { attrs: { design } };
  throw new Unsupported(
    `font-family: ${rest.length === 0 ? first : raw} has no PostScript name in the fonts option`,
  );
}
