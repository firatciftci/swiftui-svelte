# Contributing

Thanks for helping out. Bug reports, fixes, docs improvements, and new elements are all welcome. For a new element or an API change, please open an issue first so we can agree on the shape before you write the code.

## Setup

You need a Mac with Xcode 26 or later, [Homebrew](https://brew.sh), Node.js 24, and pnpm, at the version pinned in `packageManager` in `package.json`.

```sh
git clone https://github.com/firatciftci/swiftui-svelte.git
cd swiftui-svelte
brew bundle
pnpm install
```

`brew bundle` installs XcodeGen and SwiftLint. swift-format comes with Xcode.

## Running the example

```sh
pnpm dev
pnpm ios:project
open example/ios/SvelteHost.xcodeproj
```

`pnpm dev` rebuilds the example's JavaScript bundle whenever you save. Run the SvelteHost scheme on a simulator, and the app reloads the bundle by itself when it changes, so most edits to the Svelte side show up without rebuilding in Xcode. Changes to the Swift package need a rebuild.

To open one catalog page right away, pass its name after `-catalog` when you launch a Debug build. The name is the page's key in `example/src/catalog/sections.ts`, such as `sonner` or `mode-watcher`. The argument is ignored in Release builds.

```sh
xcrun simctl launch --terminate-running-process booted com.example.SvelteHost -catalog sonner
```

Use it when you want to check one example without tapping through the Catalog tab.

To try the dev server instead, run `pnpm vite --host` and set `SVELTE_SOURCE` to the bundle's address when you launch a Debug build. In the simulator, that looks like this:

```sh
SIMCTL_CHILD_SVELTE_SOURCE=http://localhost:5173/app.js xcrun simctl launch --terminate-running-process booted com.example.SvelteHost
```

On a device, add `SVELTE_SOURCE` to the scheme's environment variables in Xcode, with your Mac's Network address from Vite's output.

On a device, JavaScriptCore runs without its JIT compiler, so the simulator is faster than a phone. To get closer to device speed in the simulator, launch the app with the JIT turned off:

```sh
SIMCTL_CHILD_JSC_useJIT=false xcrun simctl launch --terminate-running-process booted com.example.SvelteHost
```

## Scripts

| Command            | What it does                                                                                                      |
| ------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `pnpm dev`         | Rebuilds the example's JavaScript bundle on every change                                                          |
| `pnpm build`       | Builds the example's JavaScript bundle once                                                                       |
| `pnpm bench`       | Builds the benchmark app instead of the example                                                                   |
| `pnpm bench:jsc`   | Measures memory and time per row in JavaScriptCore with the JIT off, using the macOS `jsc` shell                  |
| `pnpm ios:project` | Generates the example's Xcode project from `example/ios/project.yml`                                              |
| `pnpm check`       | Type checks the package and the example with `svelte-check`                                                       |
| `pnpm lint`        | Runs knip, ESLint, and SwiftLint                                                                                  |
| `pnpm lint:fix`    | Runs the same linters and applies their fixes                                                                     |
| `pnpm format`      | Checks formatting with oxfmt and swift-format                                                                     |
| `pnpm format:fix`  | Formats every file with oxfmt and swift-format                                                                    |
| `pnpm package`     | Builds the npm package into `dist` and checks it with publint and Are the Types Wrong?                            |
| `pnpm test`        | Runs the JavaScript tests with Vitest, including the budget for bundle size                                       |
| `pnpm test:swift`  | Runs the Swift package's tests, and fails on any compiler warning                                                 |
| `pnpm elements`    | Regenerates `src/known.ts`, the element and attribute names that development builds check, from `src/elements.ts` |
| `pnpm docs`        | Regenerates `docs/reference.md` from the TSDoc in `src/elements.ts` and the examples in `example/src/catalog`     |

## Project layout

| Path                    | Contents                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `src`                   | The npm package: the custom renderer, the element types, the Vite plugin, and the host polyfills |
| `Sources/SvelteSwiftUI` | The Swift package: `SvelteView`, the JavaScriptCore runtime, and the SwiftUI interpreter         |
| `example/src`           | The example app and the benchmark, written in Svelte                                             |
| `example/ios`           | The iOS host app for the example, generated with XcodeGen                                        |
| `docs`                  | The guides, and the element reference that `pnpm docs` generates                                 |

## Adding an element

An element touches both sides of the bridge:

1. Add its attributes and events to `src/elements.ts`, so that `svelte-check` includes them. Then run `pnpm elements`, so development builds don't warn about them.
2. Render it in `Sources/SvelteSwiftUI/NodeView.swift`. Read attributes from `node.attributes`, and send events back to Svelte with `runtime.dispatch`. A modifier that every element shares also goes in a group in `ModifierSet.swift`, because a modifier only applies when one of its groups is on. `test/parity.test.ts` fails when an attribute or event in `src/elements.ts` has no reader in Swift, when Swift reads an attribute that no type declares, when a shared modifier has no group, and when the bridge globals that `ScriptEngine.swift` installs differ from the ones that `src/globals.d.ts` declares.
3. Add an example to `example/src/catalog/elements`, named after the element, and list the element in `example/src/catalog/sections.ts`. The example app shows it in the Catalog tab, `test/catalog.test.ts` renders it, and `pnpm docs` generates the element reference from it. The generator fails if an element or modifier has no example. A new modifier goes in a group in `sections.ts`, and that group's example has to use it.

## Pull requests

- Keep each pull request to one change.
- Run `pnpm check`, `pnpm lint`, and `pnpm format` before you push. CI runs these, builds the npm package and the example's bundle, builds the Swift package and the example app with Xcode, and runs SwiftLint's analyzer on the build. It also runs the Swift tests and the example app's UI tests on simulators, with the UI tests split across three jobs. CI skips the simulator jobs and the build of the app template when a change only touches `docs/` or top-level Markdown files.
- `test/vite.test.ts` builds a one-line app in production mode and fails when the bundle grows past its budget of about 194 KB minified or 60 KB gzipped. If a change needs the extra bytes, raise the budget in the same pull request and say why in its description.
- `test/bench.test.ts` creates, updates, swaps, reverses, and clears 1,000 and 10,000 rows. It fails when an operation sends more ops across the bridge than its budget, or takes several times longer than it does on a laptop. Op counts don't depend on the machine, so a higher count means the renderer is doing more work. `Tests/SvelteSwiftUITests/BenchmarkTests.swift` does the same for the Swift side, applying those batches to the node store. Raise a budget only when a change needs it, and say why in the pull request.
- `test/bench.test.ts` also runs the benchmark in `test/jsc` on macOS. It builds a production bundle of a dozen row shapes, such as a plain `txt`, a component that passes its children through, and a `zstack` with a hover listener. Then it runs that bundle in the `jsc` shell that ships with macOS, with the JIT off as it is on a device. For each shape, it measures the bytes per row on the JavaScript heap after a full garbage collection, the bytes still held after unmounting, and the time to mount 1,000 rows, update their labels, swap two of them, and unmount them. Memory per row is nearly the same from run to run, so its budgets leave about 10% headroom. The time budgets are generous. Run `pnpm bench:jsc` to print the numbers. The test is skipped where there's no `jsc` shell, such as on Linux.
- `test/docs.test.ts` compiles every Svelte snippet in the README and the guides. Run `pnpm docs` after you change `src/elements.ts` or a catalog example; CI fails when `docs/reference.md` is out of date.
- The Swift package builds in Swift 6 language mode with complete concurrency checking, and `pnpm test:swift` and CI treat every warning as an error. `test/parity.test.ts` fails when `Sources` uses `@unchecked Sendable`, `nonisolated(unsafe)`, or `dispatchPrecondition`. JavaScript runs on the `ScriptEngine` actor, whose executor is its serial queue: Call into it with `engine.sync` or `engine.async`, and reach its state from a callback on that queue with `engine.assumeIsolated`.
- Try the change in the example app on a simulator. If it changes how something looks, add a screenshot to the pull request.
- Write the pull request title as a [Conventional Commit](https://www.conventionalcommits.org), such as `feat: add a picker element`. Pull requests are squash-merged, and the title becomes the commit message and the changelog entry.

## Versioning

swiftui-svelte follows [semantic versioning](https://semver.org). The public API is what the package exports and the Swift package's public types, such as `SvelteView`, `SvelteRuntime`, `NativeModule`, and `NativeComponent`. The package exports `swiftui-svelte`, `/app`, `/components`, `/elements` (the element types), `/env`, `/eslint`, `/kit` with its `/kit/environment`, `/kit/navigation`, `/kit/paths`, and `/kit/state` subpaths, `/mode-watcher`, `/native`, `/query`, `/renderer`, `/sonner`, `/tailwind`, `/tailwind/theme.css`, `/tsconfig`, and `/vite`. Anything else in `dist` is internal and can change in any release.

- **Patch releases** fix bugs and don't change the public API.
- **Minor releases** add elements, attributes, components, and Swift API. They can widen the supported Svelte range.
- **Major releases** remove or rename API, change how an element renders on purpose, narrow the supported Svelte range, or raise the minimum iOS version.

The npm package and the Swift package always ship together with the same version number, and `SvelteView` rejects a bundle built for a different bridge protocol. Before something is removed, a minor release marks it as deprecated: TSDoc `@deprecated` in TypeScript, `@available(*, deprecated)` in Swift, and a note in the changelog that names the replacement. It's removed in the next major release, at the earliest. Until 1.0.0, minor releases can include breaking changes, and the changelog lists them first.

## Releasing

Maintainers release from `main`:

1. Run `pnpm release` and choose the version. It updates `package.json`, commits, tags, and pushes.
2. The tag starts the Release workflow, which builds the package and stages it on npm through trusted publishing, so no npm token is stored in the repository. It also writes the GitHub release notes from the commit history.
3. Approve the staged version on npmjs.com to publish it.

Swift Package Manager reads versions from the same tags, so the npm package and the Swift package always release together.
