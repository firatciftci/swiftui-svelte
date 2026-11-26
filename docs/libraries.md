# Libraries

Four libraries work in a swiftui-svelte app without changes to the app's code: TanStack Query, tRPC, oRPC, and Better Auth. Each of the four talks to a server through `fetch` or `EventSource`, which the host provides, and this page covers the setup each one needs. svelte-sonner and mode-watcher also run unchanged, through native versions described at the end of this page.

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

`httpSubscriptionLink` uses the host's `EventSource`, which reconnects after a dropped connection and sends `Last-Event-ID` with each reconnect, so tracked events resume where they stopped. The host has no page, so there's no cross-site rule to apply. A subscription request sends the same cookies as any other request to that server.

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
