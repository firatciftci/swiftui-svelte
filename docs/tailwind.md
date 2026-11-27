# Tailwind CSS

swiftui-svelte reads Tailwind CSS utility classes on native elements and turns them into native attributes at build time. A `vstack` with `class="p-4 bg-white dark:bg-neutral-800"` gets padding, a background color, and a dark mode color. The app ships no CSS engine to the device.

## Set up Tailwind

Add `tailwindcss` and `postcss` as dev dependencies. Create a stylesheet that imports Tailwind and the swiftui-svelte theme, then add the plugin to `vite.config.ts` next to the `swiftui` plugin:

```ts
import { tailwind } from "swiftui-svelte/tailwind";

export default {
  plugins: [tailwind({ css: "src/app.css", sources: ["src"] })],
};
```

```css
@import "tailwindcss";
@import "swiftui-svelte/tailwind/theme.css";
```

The theme adds the platform variants and the native utilities described below. The same class strings also work in a browser build, where plain Tailwind applies them.

The plugin takes these options:

- `css` is the stylesheet that imports Tailwind and holds your `@theme` values.
- `sources` lists the folders to scan for class names. The default is `["src"]`.
- `fonts` maps a font family name to a PostScript font name. See [Fonts](#fonts).
- `ignore` is a list of class names, or `*` patterns such as `underline-offset-*`, that you accept losing. The plugin doesn't warn about them. See [Unsupported utilities](#unsupported-utilities).

## How classes apply

At build time, the plugin scans your source for class names, compiles them with Tailwind, and records the native attributes each one sets. At runtime, an element looks up its classes in that table.

Write each class name in full in your source. A name built at runtime, such as `` `bg-${color}` ``, is not in the table, so the build can't find it, and development builds warn about it.

When an attribute appears in both the `class` and the element itself, the element's attribute wins:

```svelte
<vstack class="p-4" padding={0}>
  <txt>No padding</txt>
</vstack>
```

This stack has no padding. Inside a class string, later rules win, as they do in CSS. Add `!` to a utility, such as `!p-0`, to make it win.

`margin`, `container`, `css`, `axis`, `boxsizing`, `selfalign`, and `linebox` exist so that Tailwind classes can set them. They're public and they work by hand, but the classes are how you're meant to use them, and their values follow CSS rather than SwiftUI.

## Variants

- `dark:` applies when the app's color scheme is dark. The app follows the device's Dark Mode setting unless you choose a mode with `ModeWatcher`, in which case the choice wins.
- `sm:`, `md:`, `lg:`, and the other width variants apply when the window is at least that wide. Widths are in points, and they use Tailwind's default breakpoints. On iPhone the window width rarely changes, but on iPad and Mac it does.
- `@sm:`, `@md:`, `@max-xs:`, and the other container variants apply based on the width of a container. See [Container queries](#container-queries).
- `hover:` applies while the pointer is over the element. It maps to the `hovered` state.
- `active:` applies while the element is pressed. It maps to the `pressed` state.
- `disabled:` applies while the element is disabled.
- `motion-safe:` and `motion-reduce:` follow the Reduce Motion setting.
- `group-hover:` and `group-active:` apply only when the group is a `btn`, and they follow its hovered and pressed states.
- `focus:` and `focus-visible:` have no effect. SwiftUI draws the focus ring for you, so these classes are accepted without a warning and do nothing.

### Platform variants

Platform variants apply based on what the host reports, not on a fixed platform:

| Variant    | Applies when                                                 |
| ---------- | ------------------------------------------------------------ |
| `ios:`     | The host reports iOS.                                        |
| `android:` | The host reports Android.                                    |
| `native:`  | The app runs on a native host, on any platform.              |
| `tv:`      | The device idiom is TV.                                      |
| `web:`     | The app runs in a browser. It never applies in a native app. |

A host reports its own platform, so the same class strings work on every host. An Android host applies `android:` classes, and an iOS host applies `ios:` classes, without any change to your source.

### Contrast, orientation, and direction

- `contrast-more:` applies when Increase Contrast is on. `contrast-less:` never applies, because no host reports reduced contrast.
- `portrait:` and `landscape:` compare the window's height and width.
- `ltr:` and `rtl:` follow the layout direction.

These are standard Tailwind variants, so they behave the same in a browser.

## Margins

Margins sit outside an element, the way they do in CSS. They are applied outside the background, border, and shadow, so a shadow never pushes the element's neighbors away. Every `m-*`, `mx-*`, `my-*`, `mt-*`, `mr-*`, `mb-*`, `ml-*`, `ms-*`, and `me-*` class works, including negative values such as `-mt-2`.

`auto` margins take the free space along an axis:

- `mx-auto` centers the element horizontally.
- `ml-auto` pushes the element to the trailing edge, and `mr-auto` pushes it to the leading edge.
- `my-auto` and the other vertical forms work the same way, along the vertical axis.

Auto margins become flexible frames. In a horizontal stack, several flexible children share the free space, so the result matches CSS only when the element is the one that takes it. Use `spacer` when you need a precise split.

## Stacks as CSS containers

A stack can take the layout classes of CSS grid and flex when they describe the layout it already has:

- `flex` and `inline-flex` lay out a stack's children in a row. `grid` and `inline-grid` lay them out in a column. Both work on either stack, and they set its direction, so `<hstack class="grid gap-1">` stacks its children in a column, as CSS does.
- `grid-cols-1` and `flex-col` on a `vstack` match its column layout. `flex-row` and `grid-flow-col` on an `hstack` match its row layout.
- Any other combination has no effect. A development build logs a warning for it, such as `grid-flow-col` on a `vstack`. Use a `grid`, `lazyvgrid`, or `lazyhgrid` element for multi-column grids.

Once a stack carries one of these classes, it follows the CSS defaults for children. Its children stretch across the cross axis, so a `vstack` child takes the stack's full content width and its background, border, and shadow fill that width. An `hstack` child stretches to the height of the tallest child. The stack's own width follows its parent: if the parent stretches it, it fills the width, and if the parent centers or aligns it, it is only as wide as its content.

Turn stretching off with `items-*` on the stack, or with `self-*` and `justify-self-*` on one child. A stack without these classes keeps the SwiftUI behavior.

The keywords `content-*`, `table-fixed`, `table-auto`, and `border-collapse` are accepted and have no effect, since SwiftUI stacks have no equivalent.

Alignment follows these rules:

- `items-*` and `justify-items-{start,center,end}` set the horizontal alignment of children in a `vstack`.
- `justify-{start,center,end}` aligns a stack's content along its main axis, inside the space the stack is given. It has no effect in a stack that takes no more space than its content.
- `justify-between`, `justify-around`, and `justify-evenly` produce a warning. Use a `spacer` instead.

## Borders

`border`, `border-t`, `border-b`, `border-l`, `border-r`, `border-x`, `border-y`, `border-s`, and `border-e` set the width of the edges they name, and `border-{color}` colors whichever edges are set. Like padding, a border takes space: the content sits inside it. The stroke is drawn in that band, so a row with `border-t py-1.5` is 1 point of border, 6 points of padding, the content, and 6 points of padding tall.

All-edge `border` follows the same model. A class-sized element keeps its size with the border inside it, as CSS does with Tailwind's `border-box` sizing: `w-40 border-2` is 160 points wide, including the 2-point border on each side. An element sized with attributes, such as `width={160}`, keeps SwiftUI's sizing, so its border is added outside the width, unless you set `boxsizing="border-box"`.

`ring-*` draws a ring outside the element's bounds, in the color that `ring-{color}` sets. Like a CSS ring, it takes no space, so the element and its neighbors don't move.

## Container queries

Container queries apply a class based on the width of an enclosing element, not the window. An element becomes a container with `@container`, or with `@container/name` when you want to name it:

```svelte
<vstack class="@container">
  <hstack class="@sm:flex-row flex-col">
    <txt>Wide enough for a row</txt>
  </hstack>
</vstack>
```

`@sm:`, `@max-xs:`, `@md/name:`, and the other container variants compare the width of the nearest container, or the nearest container with that name. The root view is the outermost unnamed container, so a `@sm:` class on a top-level element compares the window's width.

The theme's default sizes are Tailwind's container sizes. A shared stylesheet can redefine the variants `sm` through `2xl` as container queries, with `@custom-variant`:

```css
@custom-variant md (@container (width >= 48rem));
```

After that, `md:` compares the nearest container, not the window. Plain `md:` without the redefinition still compares the window width.

## Text

- `text-balance` (`text-wrap: balance`) makes the lines of a text element come out an even width. It keeps the same number of lines the text would have at the available width, and it uses the narrowest width that keeps that count.
- `text-pretty` has no effect. It is accepted without a warning, and text wraps as it does without it.
- `text-wrap` and `text-nowrap` follow the same rules as the other text classes, and `text-balance` works on text with spans.
- `leading-[normal]` removes the line height that another class sets, such as the one that comes with `text-sm`, so the text keeps the font's own line height.
- `max-w-full`, `max-w-none`, `max-h-full`, and `max-h-none` set no maximum, as in CSS, where a maximum of 100% never makes an element grow. They also remove a maximum that an earlier class set.

## Safe areas

In SwiftUI, content already sits inside the safe area. An element reaches the edges of the screen only if it sets `ignoressafearea`, so safe-area utilities matter most on those elements:

```svelte
<vstack ignoressafearea class="pt-safe pb-safe-or-4">
  <txt>Clear of the notch and the home indicator</txt>
</vstack>
```

These utilities read the insets that the host reports, and they update when the insets change:

- `p-safe`, `px-safe`, `py-safe`, `pt-safe`, `pr-safe`, `pb-safe`, `pl-safe`, `ps-safe`, and `pe-safe` add the inset as padding.
- `m-safe` and the other margin forms add the inset as a margin, like any margin.
- `pb-safe-offset-4` adds the inset to a spacing value. `pb-safe-or-4` uses the larger of the inset and the spacing value. Arbitrary values work too, such as `pb-safe-or-[2px]`. The offset and "or" forms exist for `p`, `px`, `py`, `pt`, `pr`, `pb`, `pl`, `m`, `mx`, `my`, `mt`, `mr`, `mb`, and `ml`.
- `h-screen-safe`, `min-h-screen-safe`, and `max-h-screen-safe` fill the safe area. SwiftUI fills the available space, so the height is not an exact measurement.
- `inset-safe` and the `top-safe`, `right-safe`, `bottom-safe`, and `left-safe` forms position an element with absolute offsets. SwiftUI doesn't have absolute positioning, so these produce a build warning.

## Native utilities

- `corner-squircle` uses continuous corners, which is already the default for `rounded-*`. `corner-rounded` uses circular corners.
- `tint-{color}` sets the tint that controls use. It also tints images that use the template rendering mode.
- `color-{color}` sets the text color, the same as `text-{color}`.
- `elevation-*` and `ripple-*` apply on Android only. On iOS they are accepted and do nothing, with no warning. An Android host reads them from the same table.

## Lengths and CSS functions

Lengths can use `calc()`, `min()`, `max()`, `clamp()`, and `round()`, with `+`, `-`, `*`, and `/`. A length that depends only on constants is computed at build time, so it costs nothing at runtime.

A length can also depend on the device, and the host measures it when the view appears and whenever it changes:

- `fontScale()` is the Dynamic Type scale, which is 1 at the default text size. On iOS it is the factor by which Dynamic Type scales the default 17-point body size, so `calc(17px * fontScale())` gives the same result as `UIFontMetrics` does at 17 points.
- `pixelRatio()` is the display scale of the device.
- `hairlineWidth()` is the thinnest line the display can draw. It equals 1 divided by the pixel ratio.
- `roundToNearestPixel(n)` rounds a length to the nearest device pixel.
- `env(safe-area-inset-top)`, and the other three edges, are the safe-area insets.
- `vw`, `vh`, `dvw`, `dvh`, `svw`, `svh`, `lvw`, and `lvh` are fractions of the viewport size that the host reports. The small, large, and dynamic forms are the same, because the host reports one size.

Use these in any length class, such as `p-[calc(env(safe-area-inset-top)+4px)]`, `w-[50vw]`, or `rounded-[roundToNearestPixel(10px)]`. They also work in `@theme` values through `var()`. A theme can scale its type with Dynamic Type:

```css
@theme {
  --text-sm: calc(0.875rem * clamp(0.8, fontScale(), 2));
  --text-sm--line-height: calc(1.25 / 0.875);
}
```

With that theme, `text-sm` grows with Dynamic Type, and its line height grows with its font size, because the line-height ratio applies to the scaled size.

Use the same functions in your own CSS, in a `@utility` or `@theme` value:

```css
@utility hairline {
  border-width: hairlineWidth();
  border-style: solid;
}
```

- `platformColor(name)` uses a system color, such as `label`, `secondaryLabel`, `systemBackground`, `separator`, or `systemGray` through `systemGray6`. An unknown name produces a build warning.

## Fonts

A `font-*` family must be a generic family or a name you map in the `fonts` option. Key the option by the first family name in the font stack, and set its value to the PostScript name of the font. For a theme font such as `--font-brand: "Avenir", sans-serif;`, the key is `Avenir`.

```ts
tailwind({
  css: "src/app.css",
  sources: ["src"],
  fonts: { Avenir: "Avenir-Medium" },
});
```

## Unsupported utilities

Utilities without a native equivalent produce a build warning. Some are accepted on purpose: `focus:` and `focus-visible:` classes do nothing, and `text-pretty` does nothing. When you accept losing an effect, such as `decoration-2` or `underline-offset-2`, list the class in the `ignore` option so the build stops warning about it:

```ts
tailwind({
  css: "src/app.css",
  sources: ["src"],
  ignore: ["decoration-2", "underline-offset-*", "@max-xs:overflow-x-auto"],
});
```

Each entry is an exact class name, or a pattern with `*` standing for any run of characters. An ignored class does nothing at runtime, and it isn't reported as unknown.

## Units and colors

`rem` and `em` both equal 16 points. Colors can be hex, `rgb`, `oklch`, `oklab`, or `color-mix` values, so Tailwind's default palette works as written.

## Performance

Class names are compiled at build time, so the device doesn't parse CSS. Elements with conditional classes are recomputed when the environment changes. Those classes include `dark:`, width variants, container variants, orientation variants, safe-area utilities, or device lengths. Other elements don't re-resolve their classes.

A container resize re-resolves only the elements inside that container.
