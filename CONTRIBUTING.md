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
| `pnpm ios:project` | Generates the example's Xcode project from `example/ios/project.yml`                                              |
| `pnpm check`       | Type checks the package and the example with `svelte-check`                                                       |
| `pnpm lint`        | Runs knip, ESLint, and SwiftLint                                                                                  |
| `pnpm lint:fix`    | Runs the same linters and applies their fixes                                                                     |
| `pnpm format`      | Checks formatting with oxfmt and swift-format                                                                     |
| `pnpm format:fix`  | Formats every file with oxfmt and swift-format                                                                    |
| `pnpm package`     | Builds the npm package into `dist` and checks it with publint and Are the Types Wrong?                            |
| `pnpm test`        | Runs the JavaScript tests with Vitest, including the budget for bundle size                                       |
| `pnpm test:swift`  | Runs the Swift package's tests                                                                                    |
| `pnpm elements`    | Regenerates `src/known.ts`, the element and attribute names that development builds check, from `src/elements.ts` |

## Project layout

| Path                    | Contents                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `src`                   | The npm package: the custom renderer, the element types, the Vite plugin, and the host polyfills |
| `Sources/SvelteSwiftUI` | The Swift package: `SvelteView`, the JavaScriptCore runtime, and the SwiftUI interpreter         |
| `example/src`           | The example app and the benchmark, written in Svelte                                             |
| `example/ios`           | The iOS host app for the example, generated with XcodeGen                                        |

## Adding an element

An element touches both sides of the bridge:

1. Add its attributes and events to `src/elements.ts`, so that `svelte-check` includes them. Then run `pnpm elements`, so development builds don't warn about them.
2. Render it in `Sources/SvelteSwiftUI/NodeView.swift`. Read attributes from `node.attributes`, and send events back to Svelte with `runtime.dispatch`.
3. Use it in the example app, and add it to the elements table in the README.

## Pull requests

- Keep each pull request to one change.
- Run `pnpm check`, `pnpm lint`, and `pnpm format` before you push. CI runs these, builds the npm package and the example's bundle, builds the Swift package and the example app with Xcode, and runs SwiftLint's analyzer on the build.
- `test/vite.test.ts` builds a one-line app in production mode and fails when the bundle grows past its budget of 180 KB minified or 55 KB gzipped. If a change needs the extra bytes, raise the budget in the same pull request and say why in its description.
- `test/bench.test.ts` creates, updates, swaps, reverses, and clears 1,000 and 10,000 rows. It fails when an operation sends more ops across the bridge than its budget, or takes several times longer than it does on a laptop. Op counts don't depend on the machine, so a higher count means the renderer is doing more work. `Tests/SvelteSwiftUITests/BenchmarkTests.swift` does the same for the Swift side, applying those batches to the node store. Raise a budget only when a change needs it, and say why in the pull request.
- Try the change in the example app on a simulator. If it changes how something looks, add a screenshot to the pull request.
- Write the pull request title as a [Conventional Commit](https://www.conventionalcommits.org), such as `feat: add a picker element`. Pull requests are squash-merged, and the title becomes the commit message and the changelog entry.

## Versioning

swiftui-svelte follows [semantic versioning](https://semver.org). The public API is what the package exports (`swiftui-svelte`, `/app`, `/components`, `/env`, `/native`, `/renderer`, `/vite`, and the element types in `/elements`) and the Swift package's public types, such as `SvelteView`, `SvelteRuntime`, `NativeModule`, and `NativeComponent`.

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
