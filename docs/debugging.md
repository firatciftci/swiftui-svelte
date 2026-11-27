# Debugging

## Reloading as you work

While you work, run the app against a bundle that rebuilds when you save, so you don't rebuild in Xcode after each change. In the simulator, point `SvelteView` at the `app.js` in your source tree and run `vite build --watch`. On a device, run `vite --host` and point `SvelteView` at the dev server. [Getting started](getting-started.md#2-show-it-in-the-ios-app) shows both setups. A reload starts the bundle over, so state that isn't saved, such as a `$state` counter, starts from its initial value again. Keep state that should survive a reload in `restorable`, which [Device environment](environment.md) describes.

## Logging

`console.log`, `console.info`, `console.warn`, `console.error`, and `console.debug` print to Xcode's console with the level in front, such as `[js:warn] Couldn't load the profile`. Objects are printed as JSON. Swift prints its own messages with a `[svelte]` or `[bridge]` prefix, so you can filter the console by prefix.

## Safari Web Inspector

To debug the JavaScript, open Safari's **Develop** menu and pick the "Svelte" context under your simulator or device. This works in Debug builds.

If Safari doesn't show a **Develop** menu, turn on **Show features for web developers** in Safari's **Advanced** settings. For a device, also turn on **Web Inspector** under **Settings › Apps › Safari › Advanced** on the device, and connect it to your Mac with a cable the first time. The inspector has the console, the sources with breakpoints, and the timelines for the JavaScript context. A bundle from `vite build --watch` or `--mode development` isn't minified, so the code you step through reads like the code you wrote.

Release builds don't mark the context as inspectable, so Safari doesn't list them.

## Errors

When the JavaScript throws, Debug builds show the error over your app, with the message, the file and line in your Svelte or TypeScript source, and the stack trace. **Reload** restarts the bundle, and **Dismiss** hides the error and leaves the app as it was. The `swiftui()` Vite plugin writes `app.js.map` next to `app.js`, and `SvelteView` uses it to turn bundle positions into source positions, so add both files to your app target. Release builds don't show the overlay: they print the error to the console and keep the last screen that rendered. To forward errors to a crash reporter, pass `onError` to `SvelteView`, as [Embedding in a Swift app](embedding.md#reporting-errors) shows.

To keep an error in one part of the screen from taking down the rest, wrap that part in `<svelte:boundary>` with a `failed` snippet. Errors that a boundary catches don't show the overlay. [Elements](elements.md) explains how boundaries work. Errors print their stack trace to the console too.

If the bundle was built with a different version of swiftui-svelte than the app's SvelteSwiftUI package, `SvelteView` shows a version mismatch screen instead of rendering. Update the npm package and the Swift package to the same version, then rebuild the bundle. The bundle also checks the app's protocol version before it mounts anything, and it logs a warning that names both versions.

## Bridge statistics

`stats` from `swiftui-svelte` counts the renderer's work. `live` is the number of element nodes that haven't been released yet, `commits` and `ops` count the batches and operations sent to the host, `bytes` is their total size, and `serializeMs` and `nativeMs` are the time spent encoding batches and the time spent inside the host's commit call. Read it to look for leaks and to compare performance between builds. `protocol` is the bridge protocol version the bundle was built with.

## Misspelled elements and attributes

While `vite build --watch` runs, or in a build with `--mode development`, the bundle also checks element and attribute names and prints a warning to Xcode's console for any it doesn't recognize, such as `<txt> doesn't have an attribute named "paddng". Did you mean "padding"?`. Each name is reported once. An element name that isn't built in renders as a red "Unknown element" label, unless you registered a native component with that name. Release builds leave the checks out.

`svelte-check` catches most of these before you build, because every element and attribute is typed. Run it with the TypeScript preset from [Getting started](getting-started.md).

## Common problems

- **The screen is blank.** Check Xcode's console for an error from the bundle, and check that `app.js` is in the app target. A bundle that fails to load shows the error in Debug builds.
- **A control snaps back.** Elements are controlled, so a `textfield` shows `value` and a `toggle` shows `checked`. Update your state in `oninput` or `onchange`, or use a component from `swiftui-svelte/components` with `bind:`.
- **`document` or `window.location` is undefined.** There's no page, so the DOM APIs aren't there. [Web APIs](web-apis.md) lists what is, and the ESLint preset reports the globals that are missing.
- **A list is slow to scroll.** Give each `{#each}` a key, and put long lists in a `list` or a lazy stack. [Performance](performance.md) has more.
- **The simulator is fast but the device is slow.** Devices run JavaScriptCore without its JIT compiler. To see device-like speed in the simulator, launch the app with the JIT turned off, as [Performance](performance.md) shows.
