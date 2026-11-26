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

The plugin takes three options:

- `css` is the stylesheet that imports Tailwind and holds your `@theme` values.
- `sources` lists the folders to scan for class names. The default is `["src"]`.
- `fonts` maps a font family name to a PostScript font name. See [Fonts](#fonts).

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

## Variants

- `dark:` applies when the device uses Dark Mode.
- `sm:`, `md:`, `lg:`, and the other width variants apply when the window is at least that wide. Widths are in points, and they use Tailwind's default breakpoints. On iPhone the window width rarely changes, but on iPad and Mac it does.
- `hover:` applies while the pointer is over the element. It maps to the `hovered` state.
- `active:` applies while the element is pressed. It maps to the `pressed` state.
- `disabled:` applies while the element is disabled.
- `motion-safe:` and `motion-reduce:` follow the Reduce Motion setting.
- `group-hover:` and `group-active:` apply only when the group is a `btn`, and they follow its hovered and pressed states.

`focus:` is not supported. Using it produces a build warning.

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

## Safe areas

In SwiftUI, content already sits inside the safe area. An element reaches the edges of the screen only if it sets `ignoressafearea`, so safe-area utilities matter most on those elements:

```svelte
<vstack ignoressafearea class="pt-safe pb-safe-or-4">
  <txt>Clear of the notch and the home indicator</txt>
</vstack>
```

These utilities read the insets that the host reports, and they update when the insets change:

- `p-safe`, `px-safe`, `py-safe`, `pt-safe`, `pr-safe`, `pb-safe`, `pl-safe`, `ps-safe`, and `pe-safe` add the inset as padding.
- `m-safe` and the margin forms add the inset as a margin. Margins map to spacing only on the bottom and trailing edges. Other margin edges produce a build warning.
- `pb-safe-offset-4` adds the inset to a spacing value. `pb-safe-or-4` uses the larger of the inset and the spacing value. Arbitrary values work too, such as `pb-safe-or-[2px]`. The offset and "or" forms exist for `p`, `px`, `py`, `pt`, `pr`, `pb`, `pl`, `m`, `mx`, `my`, `mt`, `mr`, `mb`, and `ml`.
- `h-screen-safe`, `min-h-screen-safe`, and `max-h-screen-safe` fill the safe area. SwiftUI fills the available space, so the height is not an exact measurement.
- `inset-safe` and the `top-safe`, `right-safe`, `bottom-safe`, and `left-safe` forms position an element with absolute offsets. SwiftUI doesn't have absolute positioning, so these produce a build warning.

## Native utilities

- `corner-squircle` uses continuous corners, which is already the default for `rounded-*`. `corner-rounded` uses circular corners.
- `tint-{color}` sets the tint that controls use. It also tints images that use the template rendering mode.
- `color-{color}` sets the text color, the same as `text-{color}`.
- `elevation-*` and `ripple-*` apply on Android only. On iOS they are accepted and do nothing, with no warning. An Android host reads them from the same table.

## CSS functions

Use these functions in your own CSS, in a `@utility` or `@theme` value:

- `hairlineWidth()` is the thinnest line the display can draw. It equals 1 divided by the pixel ratio.
- `pixelRatio()` is the display scale of the device.
- `fontScale()` is the Dynamic Type scale, which is 1 at the default text size.
- `roundToNearestPixel(n)` rounds a length to the nearest device pixel.
- `platformColor(name)` uses a system color, such as `label`, `secondaryLabel`, `systemBackground`, `separator`, or `systemGray` through `systemGray6`. An unknown name produces a build warning.

```css
@utility hairline {
  border-width: hairlineWidth();
  border-style: solid;
}
```

## Fonts

A `font-*` family must be a generic family or a name you map in the `fonts` option. The option maps a family name to the PostScript name of the font:

```ts
tailwind({
  css: "src/app.css",
  sources: ["src"],
  fonts: { sans: "Avenir-Medium" },
});
```

## Units and colors

`rem` and `em` both equal 16 points. Colors can be hex, `rgb`, `oklch`, `oklab`, or `color-mix` values, so Tailwind's default palette works as written.

## Performance

Class names are compiled at build time, so the device doesn't parse CSS. Elements with conditional classes, such as `dark:`, width variants, orientation variants, or safe-area utilities, are recomputed when the environment changes. Other elements don't re-resolve their classes.
