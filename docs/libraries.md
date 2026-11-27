# Libraries

Four libraries work in a swiftui-svelte app without changes to the app's code: TanStack Query, tRPC, oRPC, and Better Auth. Each of the four talks to a server through `fetch` or `EventSource`, which the host provides, and this page covers the setup each one needs. svelte-sonner and mode-watcher also run unchanged, through native versions described at the end of this page. Markdown files compiled by mdsvex render too, because the host draws the HTML tags that mdsvex writes. Charts built with d3's scale and shape modules render as well, because the host draws SVG.

## TanStack Query

TanStack Query needs two small changes, because its default focus and online handling assume a browser. Its focus manager listens for `visibilitychange` on `window`, which a swiftui-svelte app never fires. Its online manager starts out online and doesn't read `navigator.onLine` when the app launches. `connectQueryManagers` from `swiftui-svelte/query` connects both managers to the app: the queries refetch when the app comes to the foreground, and they pause while it's in the background. The online state follows `navigator.onLine` and the `online` and `offline` events.

```ts
// src/queries.ts
import {
  focusManager,
  onlineManager,
  QueryClient,
} from "@tanstack/svelte-query";
import { connectQueryManagers } from "swiftui-svelte/query";

connectQueryManagers({ focusManager, onlineManager });

export const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 60_000 } },
});
```

Call `connectQueryManagers` once, before the app mounts. Then give the client to `QueryClientProvider` in your root component, as you would on the web.

The devtools package, `@tanstack/svelte-query-devtools`, renders in the DOM, so it doesn't run in the app. Use the query client's own state in a screen when you need to inspect it.

## tRPC

`@trpc/client` works with `httpBatchLink`, `httpBatchStreamLink`, `httpLink`, and `httpSubscriptionLink`, with the `superjson` transformer on both the client and the server. Batched queries share one request, and a query that returns an async generator streams its values through `httpBatchStreamLink`.

```ts
// src/trpc.ts
import {
  createTRPCClient,
  httpBatchLink,
  httpSubscriptionLink,
  splitLink,
} from "@trpc/client";
import superjson from "superjson";
import type { AppRouter } from "../server/router.ts";

const url = "https://api.example.com/trpc";

export const trpc = createTRPCClient<AppRouter>({
  links: [
    splitLink({
      condition: (operation) => operation.type === "subscription",
      true: httpSubscriptionLink({ url, transformer: superjson }),
      false: httpBatchLink({ url, transformer: superjson }),
    }),
  ],
});
```

`httpSubscriptionLink` uses the host's `EventSource`, which reconnects after a dropped connection and sends `Last-Event-ID` with each reconnect, so tracked events resume where they stopped. A subscription request sends cookies only when the `EventSource` has `withCredentials: true`, which you set through the link's `eventSourceOptions`. [Web APIs](web-apis.md) explains which requests send cookies.

## oRPC

`RPCLink` from `@orpc/client/fetch` calls procedures over `fetch`. An event iterator, such as a procedure that returns an async generator, streams as server-sent events, and the client reads it with `for await`.

```ts
// src/orpc.ts
import { createORPCClient } from "@orpc/client";
import { RPCLink } from "@orpc/client/fetch";
import type { RouterClient } from "@orpc/server";
import type { router } from "../server/router.ts";

export const client = createORPCClient<RouterClient<typeof router>>(
  new RPCLink({ url: "https://api.example.com/rpc" }),
);

for await (const tick of await client.ticker()) {
  console.log(tick);
}
```

## Better Auth

Use the Svelte entry, `better-auth/svelte`, which keeps the session in a store that works with `$session`. Set `baseURL` to an absolute URL. The host has no page location to resolve a relative path against.

```ts
// src/auth-client.ts
import { createAuthClient } from "better-auth/svelte";

const origin = "https://api.example.com";

export const authClient = createAuthClient({
  baseURL: origin,
  fetchOptions: { headers: { Origin: origin } },
});
```

Send the `Origin` header on every request. Better Auth checks the `Origin` of each POST, and it rejects a POST without one. A native app doesn't send `Origin`, so the client has to add it. Use the same origin as `baseURL`, which the server trusts already. Any other origin, such as a custom URL scheme, needs to be listed under `trustedOrigins` on the server.

```svelte
<script lang="ts">
  import { onActive } from "swiftui-svelte/app";
  import { authClient } from "./auth-client.ts";

  const session = authClient.useSession();

  let email = $state("");
  let password = $state("");
  let failure: string | null = $state(null);

  async function signIn() {
    const result = await authClient.signIn.email({ email, password });
    failure = result.error?.message ?? null;
  }

  $effect(() => onActive(() => void session.get().refetch()));
</script>

<navstack>
  <screen title="Sign in">
    <list>
      {#if $session.data}
        <txt>Signed in as {$session.data.user.email}</txt>
      {:else}
        <textfield
          placeholder="Email"
          value={email}
          oninput={(value) => (email = value)}
        />
        <securefield
          placeholder="Password"
          value={password}
          oninput={(value) => (password = value)}
        />
        <btn variant="prominent" onclick={signIn}>Sign in</btn>
        {#if failure != null}
          <txt>{failure}</txt>
        {/if}
      {/if}
    </list>
  </screen>
</navstack>
```

The focus refetch in Better Auth's client never runs here, because it listens for `visibilitychange` on `document`. The `onActive` line above refetches the session when the app comes to the foreground.

Social sign-in doesn't work yet. Better Auth's client sends the browser to the provider by assigning `window.location`, and the host has no way to open a sign-in page in a web authentication session. `signIn.social` still returns the provider URL, so you can open it yourself, but the callback needs a native module for web authentication sessions, which the host doesn't include yet.

## mdsvex

[mdsvex](https://mdsvex.pngwn.io) compiles Markdown files to Svelte components, and those components run unchanged in the app. The host draws the HTML tags that mdsvex writes with SwiftUI views: headings, paragraphs, lists, block quotes, code blocks, horizontal rules, images, and tables. Add the mdsvex plugin before the Svelte plugin, and give the Svelte plugin the `.md` extension:

```ts
// vite.config.ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { mdsvex } from "mdsvex";
import { swiftui } from "swiftui-svelte/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    mdsvex({ extensions: [".md"] }),
    svelte({ extensions: [".svelte", ".md"] }),
    swiftui({ entry: "src/main.ts", outFile: "ios/MyApp/JavaScript/app.js" }),
  ],
});
```

TypeScript needs a declaration for `.md` imports. Put it in a `.d.ts` file of its own, such as `src/markdown.d.ts`:

```ts
declare module "*.md" {
  import type { Component } from "svelte";

  const component: Component;
  export default component;
}
```

Then import a Markdown file like any other component. Put it in a `scrollview` so that a long document scrolls:

```svelte
<script lang="ts">
  import Guide from "./guide.md";
</script>

<scrollview>
  <vstack spacing={12} padding>
    <Guide />
  </vstack>
</scrollview>
```

Each block fills the width and starts at the leading edge, as it does on the web, and the `vstack` around the document sets the space between blocks. Headings use the title text styles, and VoiceOver reads them as headings. VoiceOver reads an image's `alt` text as its label, and links open in the browser. Code blocks scroll sideways instead of wrapping. mdsvex's syntax highlighting adds `class` names to the code, but those classes have no styles in the app, so code shows in one color.

## d3 and SVG

d3's scale, shape, and array modules compute numbers and path strings without touching the DOM, so they run unchanged. Use them the way Svelte's own d3 examples do: compute the values in the script and write the SVG in the markup. The host draws an `svg` element and everything inside it with one SwiftUI `Canvas`.

```svelte
<script lang="ts">
  import { scaleLinear } from "d3-scale";
  import { line } from "d3-shape";

  const values = [3, 7, 4, 9];
  const x = scaleLinear().domain([0, 3]).range([0, 300]);
  const y = scaleLinear().domain([0, 10]).range([150, 0]);
  const path = line<number>()
    .x((_, index) => x(index))
    .y((value) => y(value))(values);
</script>

<svg width="300" height="150" viewBox="0 0 300 150" aria-label="Weekly visits">
  <path d={path} fill="none" stroke="steelblue" stroke-width="2" />
</svg>
```

The host draws `path`, `rect` (with `rx` and `ry`), `circle`, `ellipse`, `line`, `polyline`, `polygon`, and `text`, and `g` groups them. `transform` takes `translate`, `scale`, `rotate`, `skewX`, `skewY`, and `matrix`, on groups and on single elements. These presentation attributes work and are inherited by children, as attributes or in `style`: `fill`, `stroke`, `stroke-width`, `fill-opacity`, `stroke-opacity`, `stroke-linecap`, `stroke-linejoin`, `stroke-dasharray`, `stroke-dashoffset`, `fill-rule`, `font-size`, `font-weight`, `font-family`, `text-anchor`, and `dominant-baseline`. `opacity`, `display="none"`, and `visibility="hidden"` work too. Colors can be CSS color names, hex, `rgb()`, `hsl()`, or `currentColor`, which follows the foreground color around the `svg`. `text` takes `x`, `y`, `dx`, and `dy`, including `em` offsets such as `dy="0.32em"`.

The `svg` sizes itself the way a browser sizes it. With `width` and `height`, it has that size. With only a `viewBox`, it fills the width and takes its height from the `viewBox` proportions. The drawing scales into the `viewBox` and is centered, unless `preserveAspectRatio` is `none`. VoiceOver reads `aria-label`, or a `title` child, as the image's label, and skips the drawing when `aria-hidden` is `"true"`.

Some SVG features don't draw: gradients, patterns, clip paths, masks, filters, markers, `use`, `image`, `foreignObject`, and `tspan` positions. Events work on the `svg` element but not on the shapes inside it. The d3 modules that change the DOM, such as d3-selection, d3-axis, d3-zoom, and d3-brush, don't run, so draw axes with `scale.ticks()` in the markup instead. LayerChart doesn't run either. Its components measure `div` elements and bind to DOM elements, which Svelte's custom renderer doesn't support.

## svelte-sonner and mode-watcher

swiftui-svelte has native versions of [svelte-sonner](https://github.com/wobsoriano/svelte-sonner) and [mode-watcher](https://mode-watcher.sveco.dev). The Vite plugin redirects imports of `svelte-sonner` to `swiftui-svelte/sonner` and imports of `mode-watcher` to `swiftui-svelte/mode-watcher`, so web code that uses them runs unchanged. The real packages render DOM elements and read `document`, so they can't run in the app.

The redirect means the real packages are never bundled. TypeScript still reads their types from the installed packages, so install them, or import from `swiftui-svelte/sonner` and `swiftui-svelte/mode-watcher` directly, which skips the redirect. Use only the options listed below. The types of the real packages include options this version doesn't support, and those compile but do nothing at runtime.

### Toasts

Place `<Toaster />` in a `zstack` above the content it should cover, usually at the root of the app. A sheet covers the root toaster, so give a sheet its own `Toaster` with an `id`, and send its toasts there with `toasterId`.

```svelte
<script lang="ts">
  import { toast, Toaster } from "svelte-sonner";
</script>

<zstack>
  <btn onclick={() => toast.success("Saved")}>Save</btn>
  <Toaster richColors />
</zstack>
```

`toast` supports `toast(message, options)`, `toast.success`, `toast.error`, `toast.info`, `toast.warning`, `toast.loading`, `toast.message`, `toast.promise`, `toast.custom`, `toast.dismiss`, and `toast.getActiveToasts`. `useSonner()` returns the active toasts. The options are `id`, `description`, `duration`, `action`, `cancel`, `closeButton`, `dismissible`, `richColors`, `toasterId`, `onDismiss`, and `onAutoClose`. Giving a toast an `id` that's already showing updates it, as `toast.promise` does when it moves from loading to success.

`Toaster` takes `id`, `theme`, `position`, `expand`, `duration`, `gap`, `visibleToasts`, `closeButton`, and `richColors`. The default look uses Liquid Glass on iOS 26 and later, and a material before that. Swipe a toast to dismiss it.

For your own look, pass a component to `toast.custom`. The component receives the `componentProps` you pass, and a `closeToast` function that dismisses the toast:

```ts
toast.custom(RatingToast, { componentProps: { stars: 4 } });
```

These options aren't supported: `title` and `description` as components, `icon`, `class`, `style`, `classes`, `unstyled`, `toastOptions`, `hotkey`, `offset`, `swipeDirections`, `pauseWhenPageIsHidden`, `invert`, and `dir`.

### Color scheme with mode-watcher

Mount `<ModeWatcher />` once, at the root. It sends the saved preference to the host, which applies it to the whole app with SwiftUI's `preferredColorScheme`. `dark:` classes and the SwiftUI environment follow the app's color scheme, so they match the choice.

- `userPrefersMode.current` is `"light"`, `"dark"`, or `"system"`, and assigning it saves the choice in `localStorage` under `mode-watcher-mode`.
- `setMode`, `toggleMode`, and `resetMode` change the preference. `toggleMode` switches between light and dark from the mode the app shows.
- `mode.current` is the mode the app shows, `"light"` or `"dark"`.
- `systemPrefersMode.current` is the device setting.

`<ModeWatcher>` accepts two of mode-watcher's props: `modeStorageKey`, the `localStorage` key the preference is saved under (`mode-watcher-mode` by default), and `defaultMode`, the preference to use when nothing is saved (`"system"` by default). The other props, such as `track`, `themeStorageKey`, and `darkClassNames`, compile but do nothing.

The `prefers-color-scheme` media query follows the device setting, not the app's choice, as it does in a browser that overrides the color scheme.
