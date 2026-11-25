# swiftui-svelte 1.0 plan

The working checklist for 1.0.0. An item is checked only when it is implemented, covered by tests, documented, and verified in the simulator if it has UI. Milestones are roughly in dependency order, and later ones depend on the earlier ones.

Items marked _(maintainer)_ need the maintainer to do them: an iPhone connected to the Mac, or approval of a staged release on npmjs.com.

## Definition of done for 1.0

- Every SwiftUI view, control, presentation, and modifier listed below is reachable from Svelte with typed attributes and events.
- Anything not listed, such as custom `Layout`, `Shape`, `Canvas` drawing, UIKit views, and third-party SwiftUI packages, is reachable through the native component and module registry, so a missing element never blocks an app.
- Svelte's own features work as they do on the web wherever the platform allows: runes, components, snippets, `{#each}`, `{#key}`, `{#await}`, `<svelte:boundary>`, transitions mapped to SwiftUI, and two-way binding through bindable components.
- The JavaScriptCore host has the web APIs that common npm packages expect.
- The JS and Swift sides check a shared protocol version at startup and fail with a clear message when they don't match.
- CI runs JS unit tests, Swift unit tests, cross-language conformance tests, and UI tests, and benchmarks enforce performance budgets.
- iOS and iPadOS are first-class. macOS and visionOS build and pass the Swift test suite.
- The docs cover every element, modifier, and API, with guides, and a project template creates a working app with one command.

## M0. Foundations

- [x] Custom renderer with a linked-list node store on both sides, so moves are O(1)
- [x] Ops batched per microtask and committed as one JSON array
- [x] Nodes released through `FinalizationRegistry`
- [x] Live reload of the bundle in the simulator
- [x] Protocol version handshake: the renderer sends its version in the first commit, and `SvelteView` shows an error screen when it doesn't match
- [x] macOS 15 and visionOS 2 in `Package.swift`, with iOS-only APIs behind `#if os(iOS)`
- [x] Test infrastructure
  - [x] Vitest for the JS package, with a fake native bridge that records ops and dispatches events
  - [x] A Swift Testing target that runs with `swift test` on macOS
  - [x] An XCUITest target in the example app, run on a simulator in CI
  - [x] Cross-language conformance: real Svelte components compiled under Node produce op logs, and Swift tests replay them and compare the resulting tree with the JS tree
  - [x] A randomized op-sequence test (insert, move, and remove) that compares both stores with a reference model
- [x] CI runs all of the above and reports coverage for JS and Swift

## M1. Bridge, protocol, and runtime

- [x] Compact op encoding: flat arrays with interned attribute and element names instead of JSON objects, decoded without `Codable` overhead
- [x] Attribute values keep `null`, booleans, numbers, strings, arrays, objects, and `Date` exactly, and the coercion rules are documented
- [x] Redundant ops in a batch are coalesced, such as an attribute set twice or an insert followed by a remove
- [x] Controlled inputs without lag or cursor jumps: native state leads, and JS echoes are ignored unless they differ from the latest native value
- [ ] Typed event payloads, including structured ones like `{ x, y }` and `{ from, to }`
- [x] Event modifiers that make sense natively: `once`, and an opt-in debounced `oninput`
- [x] `requestAnimationFrame` and `cancelAnimationFrame`, driven by `CADisplayLink`
- [x] JS exceptions: in debug builds, an error overlay with the message, the stack, and the source-mapped location; in release builds, the error is logged and the last good tree stays on screen
- [x] The failed snippet of `<svelte:boundary>` renders natively
- [x] Source maps: Vite emits them, and the runtime maps stack traces with them
- [ ] Safari Web Inspector works with debug builds in the simulator and on devices (verify `isInspectable` and document it)
- [x] Measure running JavaScriptCore off the main thread, with ops applied on the main actor, and adopt it if it cuts main-thread time without adding a frame of latency
- [ ] A startup time budget: measure cold start to first frame on a device, and speed up bundle evaluation _(maintainer)_
- [x] Memory: no leaked nodes or listeners after mounting and unmounting 10,000 elements (tested)
- [x] Several `SvelteView` instances in one app, each with its own context, plus an option to share one
- [x] Props from Swift: `SvelteView(source:props:)`, where updating the props re-renders and the component can call back into Swift

## M2. Web platform APIs in the host

- [x] `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval`, and `queueMicrotask`
- [x] `console` methods routed to the Xcode console
- [x] Basic `fetch` through `URLSession`, and `localStorage` through `UserDefaults`
- [x] Complete `fetch`: `Request`, `Headers`, `Response` (`json`, `text`, `arrayBuffer`, and `blob`), `AbortController` and `AbortSignal`, timeouts, binary bodies, redirects, status text, and `FormData` and `URLSearchParams` bodies
- [x] `URL` and `URLSearchParams`
- [x] `TextEncoder` and `TextDecoder`
- [x] `EventTarget`, `Event`, and `CustomEvent`
- [x] `AbortController`, `AbortSignal`, and `AbortSignal.timeout`
- [x] `crypto.getRandomValues`, `crypto.randomUUID`, and `crypto.subtle.digest`
- [x] `structuredClone`
- [x] `atob`, `btoa`, `Blob`, and `File`
- [x] `WebSocket` through `URLSessionWebSocketTask`
- [x] `sessionStorage`, kept in memory
- [x] `navigator.language`, `navigator.languages`, and `navigator.onLine`, with `online` and `offline` events
- [x] `performance.now`, `performance.mark`, and `performance.measure`
- [x] `matchMedia` for `prefers-color-scheme` and `prefers-reduced-motion`
- [x] Every API tested with the same assertions in Node and in JavaScriptCore
- [x] Global `ReadableStream`, `WritableStream`, `TransformStream`, `TextDecoderStream`, and `TextEncoderStream`, so that streaming libraries such as SSE parsers and AI SDKs work

## M3. Svelte integration and ergonomics

- [x] Bindable components in `swiftui-svelte/components` (`TextField`, `Toggle`, `Picker`, `Slider`, `Stepper`, `DatePicker`, `TabView`, `Sheet`, and others), so `bind:value`, `bind:checked`, `bind:selection`, and `bind:presented` work
- [x] Transitions: `transition`, `in`, and `out` attributes map to SwiftUI transitions (`opacity`, `scale`, `slide`, `move`, `push`, and combinations), with `animation` options (`spring`, `easeInOut`, duration, and bounce)
- [x] Per-update animation: a `withAnimation(fn, options)` helper that animates the next commit
- [x] A reactive environment module, `swiftui-svelte/env`, with the color scheme, Dynamic Type size, locale, layout direction, size class, scene phase, safe area insets, reduce motion, and keyboard height
- [x] App lifecycle events: active, inactive, background, memory warning, and open URL
- [x] Focus management: a `focused` attribute, plus `focus()` and `blur()` methods through a ref helper
- [x] Element refs: Svelte rejects `bind:this` in custom renderer components, so `ref()` attachments provide `focus`, `blur`, `scrollIntoView`, `scrollTo`, and `measure`
- [x] Snippets as attachments (`header`, `footer`, `label`, `background`, and `overlay`) wherever SwiftUI takes a view builder
- [x] Rich text: nested `txt` spans with their own font, color, and weight concatenate into one `Text`, plus a `markdown` attribute
- [x] Localization: the device locale is exposed to JS and works with Paraglide, and right-to-left layout follows the locale

## M4. Element coverage

Every element is typed in `elements.ts`, rendered in Swift, shown in the example catalog, covered by a conformance test (and a UI test if it's interactive), and documented.

### Layout

- [x] `vstack`, `hstack`, `zstack`, `spacer`, `divider`, `scrollview`, and `list`
- [x] Full parameters for `vstack`, `hstack`, and `zstack`: `alignment` for every alignment guide, and `spacing`
- [x] `lazyvstack` and `lazyhstack`, with pinned section headers
- [x] `lazyvgrid` and `lazyhgrid`, with fixed, flexible, and adaptive columns
- [x] `grid` and `gridrow`, with cell spans and alignment
- [x] `viewthatfits`
- [x] `group`, `groupbox`, `controlgroup`, and `disclosuregroup` (with `expanded` and `ontoggle`)
- [x] `scrollview` axes, indicators, scroll position, `onscroll`, paging, and `scrollTo`
- [x] `spacer` `minlength`
- [x] An `onresize` event that reports an element's size, in place of `GeometryReader`

### Text and images

- [x] `txt` with `lines` and `align`, `sfsymbol`, and `asyncimage`
- [x] `txt` styles: size, design (`rounded`, `serif`, and `monospaced`), italic, underline, strikethrough, kerning, line spacing, truncation mode, minimum scale factor, and `selectable`
- [x] `txt` collapses whitespace the way browsers do, and `whitespace` keeps line breaks (`pre-line`) or every space (`pre`)
- [x] `label` (a title plus a symbol)
- [x] `image` from the asset catalog and from bundle files, with resizing, rendering mode, and symbol variants and effects
- [x] `asyncimage` phases: placeholder and failure snippets
- [x] `link` and `sharelink`
- [x] Shapes: `rectangle`, `roundedrectangle`, `circle`, `capsule`, `ellipse`, `unevenroundedrectangle`, and `path` from an SVG path string, with fill and stroke
- [x] Colors: hex, RGB, opacity, semantic system colors, linear, radial, and angular gradients, and materials

### Controls

- [x] `btn`, `textfield`, `toggle`, `picker`, `slider`, `stepper`, `datepicker`, and `progressview`
- [x] `btn` styles: `plain` and `glass`, control size, button border shape, and `repeat`
- [x] `textfield` options: keyboard type, content type, autocapitalization, autocorrection, submit label, `axis` for multiline input, and number formats
- [x] `securefield` and `texteditor`
- [x] `toggle` styles (`switch` and `button`)
- [x] `picker` with multiple selection in lists
- [x] `multidatepicker` and `colorpicker`
- [x] `gauge`
- [x] `menu`, with nested sections, buttons, toggles, and pickers, and a primary action
- [x] `contentunavailableview`
- [x] `labeledcontent`

### Navigation and presentation

- [x] `navstack` with a Svelte-owned path, `screen`, `tabview`, `tab`, `sheet`, `alert`, `toolbar`, and `swipeactions`
- [x] `navsplitview` with two and three columns and column visibility
- [x] `tabview` selection, badges, `page` style, tab sections, and the sidebar-adaptable style
- [x] `screen` title display mode, toolbar visibility, a hidden back button, toolbar background, and subtitle
- [x] `fullscreencover`, `popover`, and `inspector`
- [x] `confirmationdialog`
- [x] `sheet` detents (fractions and heights), drag indicator, locked interactive dismissal, and background interaction
- [x] `toolbar` items in every placement, menus in toolbars, and `toolbaritemgroup` spacing
- [x] `searchable`, with tokens, suggestions, scopes, and `onsubmit`
- [x] `refreshable`, with an async handler that SwiftUI awaits
- [x] `contextmenu`, with a preview
- [x] `list` selection, edit mode, `onmove`, `ondelete`, list styles, row insets, separators, row background, and section index
- [x] Deep links: open URL events and helpers for restoring navigation

### Modifiers

- [x] `padding`, `width`, `height`, `font`, `weight`, `color`, `tint`, `background`, `radius`, `opacity`, and `animated`
- [x] `padding` per edge and per axis
- [x] `frame` minimum, maximum, and ideal sizes, infinity, and alignment
- [x] `offset`, `position`, `rotation`, `scale`, `zindex`, and `aspectratio`
- [x] `overlay` and `background` with views (snippets) and shapes
- [x] `border`, `shadow`, `blur`, `clipshape` with every shape, and `mask`
- [x] `hidden`, `disabled`, `ignoressafearea`, `safeareainset`, and `contentshape`
- [ ] Accessibility: `a11ylabel`, `a11yhint`, `a11yvalue`, traits, `a11yhidden`, sort priority, combined children, and `testid` (the accessibility identifier)
- [ ] Gestures: `ontap` with count and location, `onlongpress`, `ondrag` with translation and velocity, `onmagnify`, and `onrotate`
- [ ] Lifecycle: `onappear`, `ondisappear`, and `ontask` (async, and canceled on disappear)
- [ ] `sensoryfeedback` (haptics)
- [ ] `scrolldismisseskeyboard` and a keyboard toolbar
- [ ] `preferredcolorscheme` and `environment` overrides (font, tint, and locale)
- [ ] Glass effects on iOS 26: `glasseffect` and `glasseffectcontainer`

## M5. Native extensibility

- [ ] A native component registry: `SvelteView(source:components:)` maps an element name to a Swift view builder that receives typed attributes, children, and an event sender
- [ ] A TypeScript declaration helper, so apps can type their own native elements
- [ ] A native module registry: Swift functions that JS calls as async functions, with typed arguments and results, plus Swift-to-JS events
- [ ] Built-in modules that apps often need: haptics, clipboard, share sheet, open URL, Keychain-backed secure storage, and file storage in the app container
- [ ] Examples: a MapKit `map` element and a camera module built with the registry

## M6. Performance

- [x] Upstream fix for reversing keyed `{#each}` (sveltejs/svelte#19440)
- [ ] Benchmarks in CI (create, update, swap, reverse, and clear 1,000 and 10,000 rows) with budgets that fail the build on a regression
- [ ] Fine-grained observation: an attribute change invalidates only the node's own view, not its parent's
- [ ] Lazy containers keep memory flat while scrolling 10,000 rows
- [ ] Main-thread time for 1,000 new rows under 16ms on an iPhone 15-class device _(maintainer)_
- [ ] A bundle size budget for the renderer and the host polyfills
- [x] Whitespace-only text nodes stay on the JS side instead of crossing the bridge, because SwiftUI never renders them
- [ ] Device results in the README, refreshed for 1.0 _(maintainer)_

## M7. Developer experience

- [ ] An `npm create swiftui-svelte` template: Vite, Svelte, TypeScript, and an Xcode project with the Swift package and a build phase that bundles the JS for release builds
- [ ] Loading the bundle from the Vite dev server on a physical device over the local network, with live reload _(maintainer)_
- [ ] Vite plugin: production minification, source maps, dev server integration, and clear errors
- [ ] `svelte-check` and ESLint config presets for apps
- [ ] Error messages for unknown elements and attributes in debug builds

## M8. Documentation

- [ ] A docs site or `docs/` folder: getting started, every element and modifier with examples, and guides (navigation, forms, loading data, native modules, performance, debugging, and App Store release)
- [ ] TSDoc on every element and attribute in `elements.ts`, so editors show docs on hover
- [ ] The example app becomes a catalog of every element, with the to-do app as a real-world sample
- [ ] Refreshed screenshots

## M9. Release

- [ ] A supported Svelte range, decided and tested in CI (the custom renderer API is experimental upstream)
- [ ] A semver and deprecation policy in CONTRIBUTING.md
- [ ] 0.x releases along the way, then 1.0.0 through the release workflow _(maintainer)_
