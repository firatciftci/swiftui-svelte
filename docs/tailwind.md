# Tailwind CSS

swiftui-svelte reads Tailwind CSS utility classes on native elements and turns them into native attributes at build time. A `vstack` with `class="p-4 bg-white dark:bg-neutral-800"` gets padding, a background color, and a dark mode color. The app ships no CSS engine to the device.

## Set up Tailwind

Add `tailwindcss` and `postcss` as dev dependencies. Create a stylesheet that imports Tailwind, then add the plugin to `vite.config.ts` next to the `swiftui` plugin:

```ts
import { tailwind } from "swiftui-svelte/tailwind";

export default {
  plugins: [tailwind({ css: "src/app.css", sources: ["src"] })],
};
```

```css
@import "tailwindcss";
```

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

## What maps to native attributes

| Utilities                                                | Native attribute                                                                     |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `p-*`, `px-*`, `py-*`, `pt-*`, `pr-*`, `pb-*`, `pl-*`    | `padding`                                                                            |
| `gap-*`, `space-x-*`, `space-y-*`                        | `spacing`                                                                            |
| `w-*`, `h-*`, `min-w-*`, `max-w-*`, `min-h-*`, `max-h-*` | Fixed sizes. Percentages are not supported, and `flex-1` fills the space in a stack. |
| `rounded-*`                                              | Corner radius. `rounded-full` rounds the corners fully.                              |
| `border`, `border-*`, `border-0`                         | `border`, with width and color                                                       |
| `ring-*`                                                 | `border`                                                                             |
| `shadow-*`                                               | `shadow`                                                                             |
| `text-*` colors and sizes                                | Text color and font size                                                             |
| `font-*`                                                 | Font size, weight, and family                                                        |
| `leading-*`                                              | Line height                                                                          |
| `text-left`, `text-center`, `text-right`                 | Text alignment                                                                       |
| `bg-*` colors                                            | `background`                                                                         |
| `bg-linear-to-*` with `from-*`, `via-*`, and `to-*`      | A linear gradient. Only `to` directions are supported.                               |
| `opacity-*`                                              | `opacity`                                                                            |
| `items-*`                                                | Alignment within a stack                                                             |
| `flex-col`                                               | A vertical stack                                                                     |
| `aspect-*`                                               | `aspectratio`                                                                        |
| `hidden` and `display: none`                             | `hidden`                                                                             |
| `overflow-hidden`                                        | Clipping to a rectangle                                                              |

Some web-only utilities have no effect on native elements and produce no warning. These include `cursor-*`, `outline-*`, `appearance-*`, `will-change-*`, `text-wrap`, `overflow-wrap`, `scrollbar-width`, and the transition property and timing utilities.

Other utilities produce a build warning that names the class and the file. Examples include CSS grid, absolute and fixed positioning, and keyframe animations.

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

Class names are compiled at build time, so the device doesn't parse CSS. Elements with conditional classes, such as `dark:` or width variants, are recomputed when the environment changes. Other elements don't re-resolve their classes.
