# swiftui-svelte

Render Svelte 5 components as native SwiftUI views, using the experimental API for custom renderers that shipped in Svelte 5.59. It's an early release: the element set covers only what the example app needs, and the API may change.

The repository holds two packages that work together:

- `swiftui-svelte` on npm: the custom renderer, the element types, and a Vite plugin that bundles your app for iOS.
- `SvelteSwiftUI`, a Swift package: a `SvelteView` that runs the bundle in JavaScriptCore and renders it with SwiftUI.

## Using it

### The Svelte app

Install the package alongside Svelte and Vite:

```sh
npm install -D swiftui-svelte svelte vite @sveltejs/vite-plugin-svelte
```

Point the Svelte compiler at the renderer in `svelte.config.js`:

```js
export default {
  compilerOptions: {
    experimental: { customRenderer: "swiftui-svelte/renderer" },
  },
};
```

Add the Vite plugin, which bundles the app into the single file the iOS app loads:

```ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";
import { swiftui } from "swiftui-svelte/vite";

export default defineConfig({
  plugins: [
    svelte(),
    swiftui({ entry: "src/main.ts", outFile: "ios/MyApp/Resources/app.js" }),
  ],
});
```

Mount your root component in `src/main.ts`:

```ts
import { mountApp } from "swiftui-svelte";
import App from "./App.svelte";

mountApp(App);
```

Add `"swiftui-svelte/elements"` to `compilerOptions.types` in `tsconfig.json`, so `svelte-check` knows the elements and their attributes.

### The iOS app

In Xcode, choose File › Add Package Dependencies, enter `https://github.com/firatciftci/swiftui-svelte`, and add the `SvelteSwiftUI` library to your app target. Then add `app.js` to the app's resources and show it with `SvelteView`:

```swift
import SvelteSwiftUI
import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      SvelteView(source: Bundle.main.bundleURL.appending(path: "app.js"))
    }
  }
}
```

With `reloadsOnChange: true`, `SvelteView` reloads whenever the file at `source` changes. In the simulator, point `source` at the file in your source tree and run `vite build --watch` to get live reload without rebuilding in Xcode. `example/ios/SvelteHost/SvelteHostApp.swift` shows how.

## Running the example

`example/` has a demo app with two tabs: a to-do list with navigation and swipe to delete, and a playground with a counter, a text field, and a sheet.

```sh
ni
nr build
nr ios:project
open example/ios/SvelteHost.xcodeproj
```

Run the `SvelteHost` scheme on a simulator. While it's running, `nr dev` rebuilds the bundle on save and the app reloads. To debug the JavaScript, open Safari's Develop menu and pick the "Svelte" context under the simulator (Debug builds only).

The simulator runs JavaScriptCore with its JIT, but apps on iOS devices can't use it. To see device-like speed, launch the app with the JIT turned off:

```sh
SIMCTL_CHILD_JSC_useJIT=false xcrun simctl launch --terminate-running-process booted com.example.SvelteHost
```

`nr package` builds the npm package into `dist/`.

## How it works

1. `src/renderer.ts` is a Svelte custom renderer. It keeps a lightweight node tree in JavaScript (Svelte needs to query it synchronously) and records every mutation as an op: `create`, `insert`, `remove`, `attr`, `unattr`, `text`, `release`.
2. Ops are batched per microtask and sent to Swift as one JSON string through `__nativeCommit`.
3. Vite bundles the app into a single IIFE at the plugin's `outFile`.
4. `SvelteView` (`Sources/SvelteSwiftUI`) runs that bundle in JavaScriptCore. `NodeStore` mirrors the tree as `@Observable` nodes, and `NodeView` interprets it recursively: `vstack` becomes a `VStack`, `btn` becomes a `Button`, and so on. Only the nodes that change are re-rendered.
5. Native events go back through `__svelteDispatch(id, type, payload)`, which calls the handlers Svelte registered with `addEventListener`.
6. The host provides `setTimeout`, `setInterval`, and `console`, plus `fetch` (backed by `URLSession`) and `localStorage` (saved in `UserDefaults`, so it survives relaunches). `fetch` covers the common case: `method`, `headers`, and a string `body` in, and `ok`, `status`, `headers`, `text()`, and `json()` out. When a JavaScript node is garbage-collected, a `FinalizationRegistry` sends `release` so Swift drops its copy too.

## Elements

The elements are typed in `src/elements.ts`, so `svelte-check` catches typos and wrong attribute values.

| Element                        | SwiftUI                        | Attributes and events                                |
| ------------------------------ | ------------------------------ | ---------------------------------------------------- |
| `navstack`                     | `NavigationStack`              | `onpop(depth)`                                       |
| `screen`                       | A screen in the stack          | `title`                                              |
| `vstack`, `hstack`             | `VStack`, `HStack`             | `spacing`, `alignment`                               |
| `zstack`, `scrollview`, `list` | `ZStack`, `ScrollView`, `List` |                                                      |
| `txt`                          | `Text`                         | `lines`, `align`                                     |
| `btn`                          | `Button`                       | `variant`, `role`, `onclick`                         |
| `sfsymbol`                     | `Image(systemName:)`           | `name`                                               |
| `asyncimage`                   | `AsyncImage`                   | `src`, `fit`                                         |
| `textfield`                    | `TextField`                    | `value`, `placeholder`, `oninput(value)`, `onsubmit` |
| `toggle`                       | `Toggle`                       | `checked`, `onchange(checked)`                       |
| `spacer`, `divider`            | `Spacer`, `Divider`            |                                                      |
| `tabview`, `tab`               | `TabView`, a tab               | `title`, `symbol` (on `tab`)                         |
| `sheet`                        | `.sheet`                       | `detent`, `ondismiss`                                |
| `swipeactions`                 | `.swipeActions`                | `edge`                                               |
| `toolbar`                      | `.toolbar`                     | `placement`                                          |
| `alert`                        | `.alert`                       | `title`, `ondismiss`                                 |

Every element also accepts `padding`, `font`, `weight`, `color`, `tint`, `background`, `radius`, `opacity`, `width`, and `height`, plus `animated`, which animates its children when they're added, removed, or reordered.

An `asyncimage` shows a spinner while it loads and scales the image to fit its frame, or to fill it with `fit="fill"`; give it a `width` and `height`. On `txt`, `lines` caps the number of lines and `align` sets the alignment of wrapped text (`leading`, `center`, or `trailing`).

`sheet`, `alert`, `toolbar`, and `swipeactions` aren't drawn where they appear. Put `sheet`, `alert`, and `toolbar` inside a `screen`. A `sheet` or `alert` is presented while it's rendered, so you show and hide it with `{#if}`; when the user dismisses it, `ondismiss` fires so you can update your state. An `alert` uses its `txt` children as the message and its `btn` children as the actions. A `toolbar` puts its children in the navigation bar, or in the bottom bar with `placement="bottom"`. A `swipeactions` inside a list row adds its buttons as the row's swipe actions. Set `variant="automatic"` on a button to use SwiftUI's default style, which in a list makes the whole row tappable.

A few names are shortened (`txt`, `btn`, `sfsymbol`) because `text`, `button`, `image`, and `symbol` are already HTML or SVG elements in `svelte/elements`, and their types can't be overridden.

## Navigation

Svelte owns the navigation stack. The first `screen` in a `navstack` is the root, and every `screen` after it is pushed on top, so pushing a screen means rendering another one, usually from an `{#each}` over a state array. When the user taps the back button or swipes back, `onpop` receives the number of pushed screens that are left, and the app trims its array to match:

```svelte
<script lang="ts">
  let stack: Array<number> = $state([]);
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="To-dos">
    <!-- a button that calls stack.push(todo.id) -->
  </screen>

  {#each stack as id, depth (depth)}
    <TodoDetail {id} onclose={() => (stack.length = depth)} />
  {/each}
</navstack>
```

Each pushed screen is a regular component, so it's mounted when it's pushed and destroyed when it's popped. Removing a screen from the array pops it with the usual animation. In the demo, the to-do list and its detail screens share state through `example/src/todos.svelte.ts`.

## Benchmark

`nr bench` builds `example/src/Bench.svelte` instead of the demo. It runs through a fixed set of scenarios on a 1,000-row `list` (create, update all, update one, toggle all, reverse, append one, simulated typing, clear, and a loop that creates and clears rows and checks that nodes get released) and logs one `BENCH` line per scenario to the console. Run `nr build` afterward to get the demo back.

Each line reports the time Svelte spent updating, the time spent serializing ops, the time Swift spent decoding and applying them, the op count and payload size, and the longest frame during the scenario, which includes SwiftUI's own rendering.

Benchmark a Release build. Debug builds of the Swift side are several times slower.

### On a device

To sign for a device, create `example/ios/Local.xcconfig` (it's ignored by git) with your team ID and a bundle ID that's free on your account, then regenerate the project:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER[sdk=iphoneos*] = com.yourname.SvelteHost
```

Then build, install, and launch with the console attached:

```sh
nr bench
nr ios:project
xcodebuild -project example/ios/SvelteHost.xcodeproj -scheme SvelteHost -configuration Release \
  -destination 'id=DEVICE_ID' -derivedDataPath example/ios/build -allowProvisioningUpdates build
xcrun devicectl device install app --device DEVICE_ID example/ios/build/Build/Products/Release-iphoneos/SvelteHost.app
xcrun devicectl device process launch --console --terminate-existing --device DEVICE_ID com.yourname.SvelteHost
```

`xcrun devicectl list devices` shows the device ID.

Results on an iPhone 17 Pro, Release build, over two runs:

| Scenario           | Svelte          | Swift   | Longest frame |
| ------------------ | --------------- | ------- | ------------- |
| Create 1,000 rows  | 79ms            | 28–31ms | 129–140ms     |
| Update all labels  | 24–33ms         | 3ms     | 33–36ms       |
| Update one label   | 1ms             | 0.1ms   | 17ms          |
| Reverse            | 122ms           | 1ms     | 139–142ms     |
| Clear              | 9–15ms          | 3–17ms  | 38–52ms       |
| Keystroke (median) | 0.6–0.9ms total |         | 52ms          |

Released nodes are cleaned up on both sides: after creating and clearing 6,000 rows, 13 to 20 nodes were still alive in JavaScript, and the same number in Swift.

### In the simulator

Apps on iOS devices run JavaScriptCore without its JIT, but the simulator has it. To get closer to device numbers, launch with the JIT turned off:

```sh
SIMCTL_CHILD_JSC_useJIT=false xcrun simctl launch --console-pty --terminate-running-process booted com.example.SvelteHost
```

With the JIT off, an iPhone 18 Pro simulator was within about 1.5 times the device numbers: Svelte took 64ms to create 1,000 rows and 82ms to reverse them, and Swift's times were about the same as on the device.

## Known gaps

- `bind:` isn't allowed on elements in custom renderer components, so inputs are controlled: pass `value` and update it in `oninput`.
- Svelte sends `checked` as `""` or removes it, the way it handles HTML boolean attributes, instead of passing the boolean through ([sveltejs/svelte#19435](https://github.com/sveltejs/svelte/issues/19435)). The host accepts both that and a real boolean, in case [#19437](https://github.com/sveltejs/svelte/pull/19437) is merged.
- JavaScript runs on the main thread, so large updates (creating or reversing 1,000 rows) block a few frames.
- In Svelte 5.59, reversing a keyed `{#each}` takes time proportional to the square of its length ([sveltejs/svelte#19439](https://github.com/sveltejs/svelte/issues/19439)). With the fix in [#19440](https://github.com/sveltejs/svelte/pull/19440), reversing 1,000 rows on the iPhone takes about 21ms in Svelte's part, down from 122ms. The longest frame falls from about 140ms to about 70ms.
- Ops are sent as JSON objects. Decoding the 1.4 MB payload for 1,000 new rows takes about 24ms of the 30ms that Swift spends.
- Animation is limited to `animated` on containers: there are no transitions, custom animations, or gestures beyond taps and swipes.
