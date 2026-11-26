# Routing

Routes are files. A `+page.svelte` file in `src/routes` is a screen, and its folder sets the URL, so `src/routes/todos/[id]/+page.svelte` is the screen for `/todos/2`. swiftui-svelte builds the navigation stack from the current route, so back buttons, swipe to go back, and deep links work without any stack code.

Render `<Router />` from `swiftui-svelte/kit` where the stack should appear. The Vite plugin reads the `routes` folder next to your entry file.

## Route files

- `+page.svelte` is a screen. Its folder sets the URL.
- `+layout.svelte` wraps the pages below it. Render `children` inside its markup.
- `+error.svelte` shows when a load function throws or no route matches. Read `page.status` and `page.error` to describe the error.
- `+page.ts` and `+layout.ts` export a `load` function. The app runs it before the screen appears, and its return value becomes `data`.

Folder names control which URLs match:

- `[id]` matches one segment and passes it as `params.id`.
- `[[id]]` matches one segment, or no segment.
- `[...path]` matches the rest of the URL.
- `[id=digits]` matches only the segments that the `digits` matcher in `src/params/digits.ts` accepts.
- `(group)` groups routes and layouts without adding a URL segment.

When more than one route matches a URL, the app picks the most specific one. Static segments win over matchers, matchers win over `[id]`, `[id]` wins over `[[id]]`, and `[[id]]` wins over `[...path]`. Two routes that match the same URLs stop the build with an error that names both.

To present a page as a sheet, export `presentation` from its module script: `<script module lang="ts">export const presentation = "sheet";</script>`.

## Load data

A `load` function runs before its screen appears. Throw `error(status, message)` from `swiftui-svelte/kit` to show the nearest `+error.svelte`, or call `redirect(status, location)` to send the user somewhere else.

```ts
import { error } from "swiftui-svelte/kit";
import type { PageLoadEvent } from "./$types";

export const load = ({ params }: PageLoadEvent) => {
  const id = Number(params.id);
  if (!todos.some((todo) => todo.id === id))
    error(404, "There's no to-do with that ID.");
  return { id };
};
```

The screen reads the result from `data`, typed through `PageProps`:

```svelte
<script lang="ts">
  import type { PageProps } from "./$types";

  const { data }: PageProps = $props();
</script>
```

The `./$types` module is generated from your route files each time the app builds. It types `data` and `params` for each route.

## Navigate

Import navigation helpers from `$app/navigation` and read the current route from `$app/state`:

- `goto(href, { replaceState })` pushes a route, or replaces the current one.
- `back()` pops the current screen.
- `popToRoot()` pops every pushed screen and returns to the first one. Import it from `$app/navigation` or `swiftui-svelte/kit`.
- `invalidate(depends)` and `invalidateAll()` run the `load` functions again.
- `beforeNavigate(callback)` can cancel a navigation, and `afterNavigate(callback)` runs once a screen appears. As in SvelteKit, `navigation.to` is `null` when the navigation leaves the app.
- `page` holds the `url`, `params`, `route`, `status`, `error`, and `data` for the current screen.

`Link` from `swiftui-svelte/kit` renders a button that calls `goto`.

## Deep links

An opened URL routes to the matching screen. The path after the app's scheme maps to the route: `yourapp://todos/2` opens `/todos/2`. To open web links too, such as universal links, list your site's hosts: `<Router hosts={["example.com"]} />` routes `https://example.com/todos/2` to `/todos/2`. The router ignores web URLs from any other host. On the simulator in a debug build, launch the app with `-route /todos/2` to open a route at startup.

## Transitions

By default, `<Router />` pushes screens onto a native navigation stack, with its navigation bar, back button, and swipe to go back. An app that draws its own header can pass `transition="fade"` instead. The router then shows only the top screen, without a navigation bar, and crossfades to the next screen with the `animation` you pass:

```svelte
<Router
  transition="fade"
  animation={{
    type: "timingCurve",
    curve: [0.25, 0.1, 0.25, 1],
    duration: 250,
  }}
/>
```

The screens share a namespace, so elements with the same `matchedid` on two screens morph from one to the other as the screens change. There is no swipe to go back in this mode. Call `back()` from your own gesture or button.

## Differences from SvelteKit

- The app has no server. There are no `+page.server.ts`, `+server.ts`, `hooks`, or form actions. Fetch data from the device or from your own API.
- Screens are native. Nested layouts render inside each screen, so they remount when the user pushes a page instead of staying mounted across navigations.
- `$app/paths` exports `base` and `assets`, which are both empty strings, plus `resolve` and `asset`. `resolve("/items/[id]", { id })` fills in the parameters and drops `(group)` segments, as it does in SvelteKit.
- `page.data` is typed as `Record<string, unknown>` because the data from every level merges into one object.
- The stack lives in one tab. Each sheet renders a single page inside its own navigation stack.
- `preloadData`, `pushState`, `replaceState`, and `page.form` are not available.

The app restores the stack when it launches, so a user who closes the app on a detail screen returns to that screen.
