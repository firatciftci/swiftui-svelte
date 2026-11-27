# Device environment, lifecycle, and localization

`swiftui-svelte/env` exports `env`, a read-only object with the values SwiftUI keeps in its environment. Reading a value in markup, `$derived`, or `$effect` subscribes to it, so the component updates when the user changes a setting, rotates the device, or opens the keyboard:

```svelte
<script lang="ts">
  import { env } from "swiftui-svelte/env";

  const isLarge = $derived(env.dynamicTypeSize.startsWith("accessibility"));
</script>

{#if isLarge}
  <vstack alignment="leading"><!-- … --></vstack>
{:else}
  <hstack><!-- … --></hstack>
{/if}
```

| Property                                                                                              | Value                                                                                                                                                       |
| ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `colorScheme`                                                                                         | `"light"` or `"dark"`: the scheme the app displays, including an override set through `mode-watcher`                                                        |
| `systemColorScheme`                                                                                   | The device's own setting, `"light"` or `"dark"`, even while the app overrides it. It updates as soon as the device's setting changes, including while the app is open |
| `liquidGlass`                                                                                         | Whether the system draws Liquid Glass: `true` on iOS 26, macOS 26, visionOS 26, and later, unless the app's Info.plist sets `UIDesignRequiresCompatibility` |
| `dynamicTypeSize`                                                                                     | SwiftUI's `DynamicTypeSize` case name, from `"xSmall"` through `"xxxLarge"` and `"accessibility1"` through `"accessibility5"`                               |
| `locale`                                                                                              | The BCP 47 identifier of SwiftUI's locale, such as `"en-US"`                                                                                                |
| `languages`                                                                                           | The user's preferred languages, in order                                                                                                                    |
| `timeZone`                                                                                            | The time zone identifier, such as `"America/Chicago"`                                                                                                       |
| `layoutDirection`                                                                                     | `"leftToRight"` or `"rightToLeft"`                                                                                                                          |
| `horizontalSizeClass`, `verticalSizeClass`                                                            | `"compact"` or `"regular"`, or `null` on macOS, which has no size classes                                                                                   |
| `scenePhase`                                                                                          | `"active"`, `"inactive"`, or `"background"`                                                                                                                 |
| `safeAreaInsets`                                                                                      | `{ top, leading, bottom, trailing }` in points, not counting the keyboard                                                                                   |
| `keyboardHeight`                                                                                      | The height of the on-screen keyboard in points, or `0` when it's hidden                                                                                     |
| `reduceMotion`, `reduceTransparency`, `increaseContrast`                                              | The accessibility settings, as booleans                                                                                                                     |
| `voiceOver`, `switchControl`, `differentiateWithoutColor`, `invertColors`, `boldText`, `buttonShapes` | Whether VoiceOver or Switch Control is running, and the matching display settings, as booleans                                                              |
| `onLine`                                                                                              | Whether the device has a network connection                                                                                                                 |

Each property is tracked separately, so an effect that reads `colorScheme` doesn't run again when the keyboard opens. Outside components, `env` returns the current value without subscribing. `SvelteView` reads these values from its own SwiftUI environment, so `.environment(\.locale, …)` and similar overrides on the view reach JavaScript too.

## App lifecycle

`swiftui-svelte/app` lets components react when the app changes state. Each function takes a listener and returns a function that removes it, so you can return it from `$effect` and the listener goes away with the component:

```svelte
<script lang="ts">
  import { onBackground, onMemoryWarning, onOpenURL } from "swiftui-svelte/app";

  $effect(() => onBackground(() => saveDraft()));
  $effect(() => onMemoryWarning(() => imageCache.clear()));
  $effect(() =>
    onOpenURL((url) => {
      if (url.host === "todos") openTodo(Number(url.pathname.slice(1)));
    }),
  );
</script>
```

- `onActive`, `onInactive`, and `onBackground` run when SwiftUI's scene phase changes to that value. While the app launches, the scene goes from inactive to active, so `onActive` also runs once at startup.
- `onMemoryWarning` runs when iOS sends a memory warning. Free what you can there. After the listeners run, JavaScriptCore collects garbage.
- `onOpenURL` receives a `URL` for each link that opens the app, such as a custom URL scheme or a universal link. `SvelteView` forwards SwiftUI's `onOpenURL` for you, and if several views share a runtime, the link still arrives once. A link that opens the app before any component listens, as on a cold launch, waits for the first listener. If your app gets URLs somewhere else, such as in an app delegate, pass them to `runtime.open(url)`.

The example app registers the `sveltehost` scheme, so `xcrun simctl openurl booted sveltehost://todos/2` opens the second to-do.

### Deep links and restoring navigation

`matchURL(pattern, url)` checks a link against a pattern and returns its parameters, or `null` if it doesn't match. A segment that starts with `:` captures one segment, and a final `*` captures the rest. For a custom scheme, the host counts as the first segment, so one pattern matches both kinds of link:

```ts
matchURL("todos/:id", "sveltehost://todos/2"); // { id: "2" }
matchURL("todos/:id", "https://example.com/todos/2"); // { id: "2" }
matchURL("notes/*", "sveltehost://notes/a/b"); // { "*": "a/b" }
```

`restorable(key, initial)` returns state whose `value` is saved to `localStorage` whenever it changes and read back on the next launch, so the app can reopen where the user left it. Use it for the navigation path or the selected tab. The saved value must be JSON. If the saved value doesn't have the same shape as `initial`, for example an array where `initial` is a string, the state starts from `initial` instead. Pass a type guard as the third argument for a stricter check, such as making sure every saved ID still exists:

```svelte
<script lang="ts">
  import { matchURL, onOpenURL, restorable } from "swiftui-svelte/app";

  const tab = restorable("tab", "home");
  const path = restorable(
    "path",
    [],
    (value): value is Array<number> =>
      Array.isArray(value) && value.every((id) => items.has(id)),
  ).value;

  $effect(() =>
    onOpenURL((url) => {
      const match = matchURL("items/:id", url);
      if (match == null) return;
      tab.value = "home";
      path.splice(0, path.length, Number(match.id));
    }),
  );
</script>

<TabView bind:selection={tab.value}>...</TabView>
```

## Localization

JavaScript starts with the device's language settings, so locale-aware code works from the first line of your app:

- `Intl`, `toLocaleString`, and `Date` use the device's language and time zone.
- `navigator.language` and `navigator.languages` list the user's preferred languages.
- `env.locale`, `env.timeZone`, and `env.layoutDirection` match the device before any component mounts.

[Paraglide](https://paraglidejs.com/) works with its usual Vite plugin. Pick the device's language with the `preferredLanguage` strategy:

```ts
// vite.config.ts
paraglideVitePlugin({
  project: "./project.inlang",
  outdir: "./src/paraglide",
  strategy: ["preferredLanguage", "baseLocale"],
}),
```

Message functions read the locale each time they run but don't subscribe to it, so a language picker inside the app needs the locale in `$state`. Overwrite `getLocale` to read it, and every message in your markup updates when it changes:

```ts
// src/language.svelte.ts
import {
  getLocale,
  getTextDirection,
  overwriteGetLocale,
} from "./paraglide/runtime.js";
import type { Locale } from "./paraglide/runtime.js";

const device = getLocale();
const selection = $state<{ locale: Locale | null }>({ locale: null });
overwriteGetLocale(() => selection.locale ?? device);

export const language = {
  get locale() {
    return getLocale();
  },
  set locale(next: Locale | null) {
    selection.locale = next;
  },
  get dir() {
    return getTextDirection(getLocale());
  },
};
```

Then set `lang` and `dir` on the root element. Like the HTML attributes, they work on any element. `lang` sets SwiftUI's locale for everything inside, so date pickers and other controls format dates and numbers for that language. `dir` is `ltr` or `rtl` and mirrors the layout, including navigation bars and the tab bar:

```svelte
<tabview lang={language.locale} dir={language.dir}>
  <!-- tabs -->
</tabview>
```

When the device itself uses a right-to-left language, iOS mirrors the app on its own, but only if the app declares that language. List every language you translate to under `CFBundleLocalizations` in the app's Info.plist. Otherwise iOS falls back to your development language, and `env.layoutDirection` stays `leftToRight`.

The example app translates its tab titles and Settings screen into Arabic with Paraglide. It follows the device's language and has a picker for choosing one, and it saves that choice in `localStorage`.
