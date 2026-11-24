# swiftui-svelte

A spike that renders Svelte 5 components as native SwiftUI views, using the experimental custom renderer API that shipped in Svelte 5.59.

## How it works

1. `src/renderer.ts` is a Svelte custom renderer. It keeps a lightweight node tree in JavaScript (Svelte needs to query it synchronously) and records every mutation as an op: `create`, `insert`, `remove`, `attr`, `unattr`, `text`, `release`.
2. Ops are batched per microtask and sent to Swift as one JSON string through `__nativeCommit`.
3. Vite bundles the app into a single IIFE at `ios/SvelteHost/Resources/app.js`.
4. The iOS host (`ios/SvelteHost`) runs that bundle in JavaScriptCore. `NodeStore` mirrors the tree as `@Observable` nodes, and `NodeView` interprets it recursively: `vstack` becomes a `VStack`, `btn` becomes a `Button`, and so on. Only the nodes that change are re-rendered.
5. Native events go back through `__svelteDispatch(id, type, payload)`, which calls the handlers Svelte registered with `addEventListener`.
6. The host provides `setTimeout`, `setInterval`, and `console`. When a JavaScript node is garbage-collected, a `FinalizationRegistry` sends `release` so Swift drops its copy too.

## Running it

```sh
ni
nr build
nr ios:project
open ios/SvelteHost.xcodeproj
```

Run the `SvelteHost` scheme on a simulator. While it's running, `nr dev` rebuilds the bundle on save. In the simulator, the app reads `app.js` straight from the source tree and reloads when it changes, so you don't need to rebuild in Xcode. On a device, the app uses the copy bundled at build time.

To debug the JavaScript, open Safari's Develop menu and pick the "Svelte" context under the simulator (Debug builds only).

## Elements

The elements are typed in `src/native.d.ts`, so `svelte-check` catches typos and wrong attribute values.

| Element                        | SwiftUI                        | Attributes and events                                |
| ------------------------------ | ------------------------------ | ---------------------------------------------------- |
| `navstack`                     | `NavigationStack`              | `onpop(depth)`                                       |
| `screen`                       | A screen in the stack          | `title`                                              |
| `vstack`, `hstack`             | `VStack`, `HStack`             | `spacing`, `alignment`                               |
| `zstack`, `scrollview`, `list` | `ZStack`, `ScrollView`, `List` |                                                      |
| `txt`                          | `Text`                         |                                                      |
| `btn`                          | `Button`                       | `variant`, `onclick`                                 |
| `sfsymbol`                     | `Image(systemName:)`           | `name`                                               |
| `textfield`                    | `TextField`                    | `value`, `placeholder`, `oninput(value)`, `onsubmit` |
| `toggle`                       | `Toggle`                       | `checked`, `onchange(checked)`                       |
| `spacer`, `divider`            | `Spacer`, `Divider`            |                                                      |

Every element also accepts `padding`, `font`, `weight`, `color`, `background`, `radius`, and `opacity`.

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

Each pushed screen is a regular component, so it's mounted when it's pushed and destroyed when it's popped. Removing a screen from the array pops it with the usual animation. In the demo, the to-do list and its detail screens share state through `src/todos.svelte.ts`.

## Benchmark

`nr bench` builds `src/Bench.svelte` instead of the demo. It runs through a fixed set of scenarios on a 1,000-row `list` (create, update all, update one, toggle all, reverse, append one, simulated typing, clear, and a create/clear churn that checks nodes get released) and logs one `BENCH` line per scenario to the console. Run `nr build` afterward to get the demo back.

Each line reports the time Svelte spent updating, the time spent serializing ops, the time Swift spent decoding and applying them, the op count and payload size, and the longest frame during the scenario, which includes SwiftUI's own rendering.

Apps on iOS devices run JavaScriptCore without its JIT, but the simulator has it. To get closer to device numbers, launch with the JIT turned off:

```sh
SIMCTL_CHILD_JSC_useJIT=false xcrun simctl launch --console-pty --terminate-running-process booted com.example.SvelteHost
```

Benchmark a Release build. Debug builds of the Swift side are several times slower.

Results on an iPhone 18 Pro simulator, Release build, JIT off:

| Scenario           | Svelte      | Swift | Longest frame |
| ------------------ | ----------- | ----- | ------------- |
| Create 1,000 rows  | 64ms        | 36ms  | 170ms         |
| Update all labels  | 12ms        | 2ms   | 17ms          |
| Update one label   | 0.2ms       | 0.0ms | 17ms          |
| Reverse            | 82ms        | 11ms  | 147ms         |
| Clear              | 8ms         | 2ms   | 45ms          |
| Keystroke (median) | 0.3ms total |       | 36ms          |

Released nodes are cleaned up on both sides: after creating and clearing 6,000 rows, 19 nodes were still alive in JavaScript and the same 19 in Swift.

## Known gaps

- `bind:` isn't allowed on elements in custom renderer components, so inputs are controlled: pass `value` and update it in `oninput`.
- Svelte sends `checked` as `""` or removes it, the way it handles HTML boolean attributes, instead of passing the boolean through ([sveltejs/svelte#19435](https://github.com/sveltejs/svelte/issues/19435)). The host accepts both that and a real boolean, in case [#19437](https://github.com/sveltejs/svelte/pull/19437) is merged.
- JavaScript runs on the main thread, so large updates (creating or reversing 1,000 rows) block a few frames.
- Ops are sent as JSON objects. Decoding the 1.4 MB payload for 1,000 new rows takes about 24ms of Swift's 36ms.
- There are no animations or transitions, gestures beyond taps and swiping back, sheets, tab views, or `List` features like swipe actions.
- None of this has been measured on a physical device yet.
