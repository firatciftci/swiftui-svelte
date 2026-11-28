# Embedding in a Swift app

`mountApp` can register several components by name, so one bundle can provide any number of screens:

```ts
mountApp({ App, Profile, Badge });
```

A `SvelteView` shows the component called `default` unless you pass `component`, which is what `mountApp(App)` registers. Pass `props` to give the component values from Swift, as a dictionary of `JSONValue`. Literals work as they are, and `JSONValue(_:)` converts a number, a `Date` (to an ISO 8601 string), or a `URL` (to a string). When props change, the component updates as it would with new props from a parent. Pass `actions` to give it functions that call back into Swift. Each action arrives as a function prop, and whatever the component passes to it reaches your closure as a `JSONValue`. Switch over its cases, or decode it into your own `Decodable` type with `decode(_:)`.

```swift
SvelteView(
    source: bundleURL,
    component: "Badge",
    props: ["count": JSONValue(count), "since": JSONValue(startDate)],
    actions: ["onreset": { _ in count = 0 }]
)
```

```svelte
<script lang="ts">
  const { count, onreset }: { count: number; onreset: () => void } = $props();
</script>

<btn onclick={() => onreset()}>Reset {count}</btn>
```

Each `SvelteView(source:)` runs its own JavaScript context. To have several views share one context, and with it the same module state and stores, create a `SvelteRuntime` once and pass it to each view:

```swift
@State private var runtime = SvelteRuntime(source: bundleURL)

var body: some View {
    TabView {
        Tab("Home", systemImage: "house") { SvelteView(runtime: runtime, component: "Home") }
        Tab("Profile", systemImage: "person") { SvelteView(runtime: runtime, component: "Profile") }
    }
}
```

A component stays mounted as long as its `SvelteView` exists, including while it's in a tab that isn't selected, and unmounts when the view goes away.

A runtime shuts down when nothing references it anymore: its timers stop, its requests and WebSockets close, and its JavaScript context is released. To shut one down earlier, for example when the user signs out and you're about to show a screen that doesn't use it, call `stop()`. If a view mounts a component on a stopped runtime, the runtime loads the bundle again and starts from scratch.

## Reporting errors

Debug builds show JavaScript errors over your app, and Release builds only print them. To send them somewhere else in every build, such as a crash reporter, pass `onError` to `SvelteView` or to `SvelteRuntime`:

```swift
SvelteView(source: bundleURL) { error in
    CrashReporter.record(error.description, kind: "\(error.kind)")
}
```

A `SvelteView(runtime:)` reports errors to its runtime, so when views share a `SvelteRuntime`, pass `onError` to the runtime or set its `onError` property.

The closure runs on the main thread with a `ScriptError`. `message` is the error's message, and `frames` is the stack, with each frame's `function` and its `location` in your source when `app.js.map` is in the app. `kind` says where the error came from:

| Kind      | When                                                                                                  |
| --------- | ----------------------------------------------------------------------------------------------------- |
| `.script` | JavaScript threw an exception that nothing caught.                                                    |
| `.bridge` | The bundle sent a batch of changes that the app couldn't read. `SvelteView` restarts the bundle once. |
| `.load`   | The bundle couldn't be loaded, for example because `app.js` is missing or the server didn't answer.   |

Errors that a `<svelte:boundary>` catches don't reach `onError`.

## Reloading the bundle

`reload()` on a `SvelteRuntime` loads the bundle again from its source and mounts every component that's showing again with its current props. Module state starts over, so use it when that state is stale as a whole, such as after the user signs in or out.
