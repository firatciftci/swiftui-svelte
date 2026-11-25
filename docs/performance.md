# Performance

## Keeping your app fast

- **Key every `{#each}`.** With a key, Svelte moves rows when the order changes instead of building them again.
- **Put long collections in a `list`, or in a lazy stack or grid inside a `scrollview`.** SwiftUI then creates rows only as they scroll into view. That works when every direct child of the container is a single row. If one of them is a `group` or a `disclosuregroup`, SwiftUI has to build every row up front to count them, so keep those out of long lists. A `sectionview` is fine as a direct child, because its rows are counted the same way.
- **Change state in place.** Setting `todo.done = true` updates one toggle, and Svelte sends only that change to Swift. Replacing the whole array makes Svelte compare every row.
- **Load big lists in pages.** Creating 1,000 rows at once takes a few frames. [Loading data](loading-data.md) shows how to load the next page as the user scrolls.
- **Debounce text fields that start work.** `debounce` on a `textfield` waits until the user stops typing before `oninput` runs.
- **Measure a Release build on a device.** The simulator runs JavaScriptCore with its JIT compiler, and devices run it without one, so the simulator can be several times faster. The next section shows how to measure.

## Measurements

On an iPhone 17 Pro, with a Release build, over two runs of the benchmark on a list of 1,000 rows:

| Scenario           | Svelte          | Swift   | Longest frame |
| ------------------ | --------------- | ------- | ------------- |
| Create 1,000 rows  | 79ms            | 28–31ms | 129–140ms     |
| Update all labels  | 24–33ms         | 3ms     | 33–36ms       |
| Update one label   | 1ms             | 0.1ms   | 17ms          |
| Reverse            | 122ms           | 1ms     | 139–142ms     |
| Clear              | 9–15ms          | 3–17ms  | 38–52ms       |
| Keystroke (median) | 0.6–0.9ms total |         | 52ms          |

"Svelte" is the time Svelte spent updating its tree, "Swift" is the time Swift spent decoding and applying the ops, and "Longest frame" includes SwiftUI's own rendering. Updates to a few nodes, like a keystroke or a single label, fit within a frame. Creating or reversing 1,000 rows at once blocks a few frames, mostly in Svelte's part.

The table above was measured with version 0.2.0. Since then, the bridge sends only what's on screen, in the compact encoding described in [How it works](../README.md#how-it-works). In an iPhone 18 Pro simulator with the JIT off and a Debug build, creating 1,000 rows now takes Swift 4ms instead of 37ms, with 1,004 ops instead of 30,008 and a 67 KB payload instead of 1.4 MB. Clearing them takes Swift under 1ms instead of 7ms.

JavaScript now runs off the main thread. In the same simulator with a Release build, the longest frame while creating 1,000 rows dropped from 124ms to 52–85ms, and while reversing them from 113ms to 46–94ms. Swift spends about 1ms on the main thread applying the ops; the rest of those frames is SwiftUI laying out the list.

Released nodes are cleaned up on both sides: after 6,000 rows were created and cleared, 13 nodes were still alive in JavaScript, and Swift held only the 7 nodes on screen.

Lazy containers keep memory flat while scrolling. In an iPhone 18 Pro simulator with a Debug build, a `list` of 10,000 rows took 240 MB when it opened and 170 MB after scrolling through 3,000 rows. A lazy stack of the same rows went from 140 MB to 156 MB. Before version 1.0, SwiftUI built every row of a `list` when it opened, which took 980 MB, and a lazy stack kept 160 MB of rows it had scrolled past. To measure it yourself, open the Playground tab of the example app, open one of the 10,000-row screens in the Navigation section, and tap **Scroll through 3,000 rows**. The label next to the button shows the memory when the screen opened, before scrolling, and after.

<details>
<summary>Running the benchmark</summary>

`pnpm bench` builds [`Bench.svelte`](../example/src/Bench.svelte) instead of the example app. It runs a fixed set of scenarios on a 1,000-row `list` (create, update all, update one, toggle all, reverse, append one, simulated typing, clear, and a loop that creates and clears rows and checks that nodes get released) and logs one `BENCH` line per scenario to the console. Run `pnpm build` afterward to get the example app back. Benchmark a Release build, because Debug builds of the Swift side are several times slower.

To sign for a device, create `example/ios/Local.xcconfig`, which git ignores, with your team ID and a bundle ID that's free on your account:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER[sdk=iphoneos*] = com.yourname.SvelteHost
```

Then build, install, and launch with the console attached. `xcrun devicectl list devices` shows the device ID.

```sh
pnpm bench
pnpm ios:project
xcodebuild -project example/ios/SvelteHost.xcodeproj -scheme SvelteHost -configuration Release \
  -destination 'id=DEVICE_ID' -derivedDataPath example/ios/build -allowProvisioningUpdates build
xcrun devicectl device install app --device DEVICE_ID example/ios/build/Build/Products/Release-iphoneos/SvelteHost.app
xcrun devicectl device process launch --console --terminate-existing --device DEVICE_ID com.yourname.SvelteHost
```

Apps on iOS devices run JavaScriptCore without its JIT compiler, but the simulator has it. To get closer to device numbers in the simulator, launch with the JIT turned off:

```sh
SIMCTL_CHILD_JSC_useJIT=false xcrun simctl launch --console-pty --terminate-running-process booted com.example.SvelteHost
```

With the JIT off, an iPhone 18 Pro simulator came within about 1.5 times the device numbers: Svelte took 64ms to create 1,000 rows and 82ms to reverse them, and Swift's times were about the same as on the device.

</details>
