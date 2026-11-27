# Embedding in a Swift app

`mountApp` can register several components by name, so one bundle can provide any number of screens:

```ts
mountApp({ App, Profile, Badge });
```

A `SvelteView` shows the component called `default` unless you pass `component`, which is what `mountApp(App)` registers. Pass `props` to give the component values from Swift. When they change, the component updates as it would with new props from a parent. Pass `actions` to give it functions that call back into Swift. Each action arrives as a function prop, and whatever the component passes to it reaches your closure as a Foundation value: a string, a number, a boolean, an array, a dictionary, or `NSNull`.

```swift
SvelteView(
    source: bundleURL,
    component: "Badge",
    props: ["count": count, "since": startDate],
    actions: ["onreset": { _ in count = 0 }]
)
```

```svelte
<script lang="ts">
  const { count, onreset }: { count: number; onreset: () => void } = $props();
</script>

<btn onclick={() => onreset()}>Reset {count}</btn>
```

Props must be JSON values. A `Date` becomes an ISO 8601 string, and a `URL` becomes a string.

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

## Reporting errors

Debug builds show JavaScript errors over your app, and Release builds only print them. To send them somewhere else in every build, such as a crash reporter, pass `onError` to `SvelteView` or to `SvelteRuntime`:

```swift
SvelteView(source: bundleURL) { error in
    CrashReporter.record(error.description, kind: "\(error.kind)")
}
```

The closure runs on the main thread with a `ScriptError`. `message` is the error's message, and `frames` is the stack, with each frame's `function` and its `location` in your source when `app.js.map` is in the app. `kind` says where the error came from:

| Kind                  | When                                                                                                     |
| --------------------- | -------------------------------------------------------------------------------------------------------- |
| `.script`             | JavaScript threw an exception that nothing caught.                                                       |
| `.unhandledRejection` | A promise was rejected and had no rejection handler. These don't show the error overlay in Debug builds. |
| `.bridge`             | The bundle sent a batch of changes that the app couldn't read. `SvelteView` restarts the bundle once.    |
| `.load`               | The bundle couldn't be loaded, for example because `app.js` is missing or the server didn't answer.      |

Errors that a `<svelte:boundary>` catches don't reach `onError`.
