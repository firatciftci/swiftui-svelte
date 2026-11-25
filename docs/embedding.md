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
