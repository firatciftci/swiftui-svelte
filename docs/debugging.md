# Debugging

## Reloading as you work

While you work, run the app against a bundle that rebuilds when you save, so you don't rebuild in Xcode after each change. In the simulator, point `SvelteView` at the `app.js` in your source tree and run `vite build --watch`. On a device, run `vite --host` and point `SvelteView` at the dev server. [Getting started](getting-started.md#2-show-it-in-the-ios-app) shows both setups. A reload starts the bundle over, so state that isn't saved, such as a `$state` counter, starts from its initial value again. Keep state that should survive a reload in `restorable`, which [Device environment](environment.md) describes.

## Logging

`console.log`, `console.info`, `console.warn`, `console.error`, and `console.debug` write to Apple's unified log under the subsystem `swiftui-svelte` and the category `javascript`, each at the matching level. Objects are logged as JSON. Xcode's console shows these messages while the app runs, and you can filter it by subsystem or category. To read them from a device that isn't attached to Xcode, open the Console app on your Mac and search for `subsystem:swiftui-svelte`.

The library's own warnings, such as a native module that replaces another module with the same name, use the category `diagnostics`. Each warning is logged once each time the bundle loads. Bridge errors and JavaScript exceptions are logged as errors.

## Safari Web Inspector

To debug the JavaScript, open Safari's **Develop** menu and pick the "Svelte" context under your simulator or device. This works in Debug builds.

If Safari doesn't show a **Develop** menu, turn on **Show features for web developers** in Safari's **Advanced** settings. For a device, also turn on **Web Inspector** under **Settings › Apps › Safari › Advanced** on the device, and connect it to your Mac with a cable the first time. The inspector has the console, the sources with breakpoints, and the timelines for the JavaScript context. A bundle from `vite build --watch` or `--mode development` isn't minified, so the code you step through reads like the code you wrote.

Release builds don't mark the context as inspectable, so Safari doesn't list them.

## Errors

When the JavaScript throws after your app has rendered, Debug builds show the error over your app, with the message, the file and line in your Svelte or TypeScript source, and the stack trace. **Reload** restarts the bundle, and **Dismiss** hides the error and leaves the app as it was. The `swiftui()` Vite plugin writes `app.js.map` next to `app.js`, and `SvelteView` uses it to turn bundle positions into source positions, so add both files to your app target. Release builds don't show the overlay: they print the error to the console and keep the last screen that rendered. To forward errors to a crash reporter, pass `onError` to `SvelteView`, as [Embedding in a Swift app](embedding.md#reporting-errors) shows.

To keep an error in one part of the screen from taking down the rest, wrap that part in `<svelte:boundary>` with a `failed` snippet. Errors that a boundary catches don't show the overlay. [Elements](elements.md) explains how boundaries work. Errors print their stack trace to the console too.

If the view never renders, `SvelteView` says why in every build, Release included. When the bundle doesn't load, or throws before it mounts the component, the view shows the error message and a **Reload** button. When the bundle loads but sends nothing for two seconds, the view says that the app didn't start, and it names the swiftui-svelte release and the bridge protocol of the bundle and of the app's SvelteSwiftUI package. A bundle from swiftui-svelte 0.2.0 or earlier doesn't report its release, and the view says so.

If the bundle was built with a different version of swiftui-svelte than the app's SvelteSwiftUI package, `SvelteView` shows a version mismatch screen that names both versions instead of rendering. Update the npm package and the Swift package to the same version, then rebuild the bundle. The bundle also checks the app's protocol version before it mounts anything, and it logs a warning that names both versions.

## Development warnings

Debug builds also collect the library's warnings in a tray. When the current bundle has reported a warning, a yellow handle appears on the leading edge of the screen with the number of warnings. Tap it to read them. **Hide** folds the list back into the handle, and **Dismiss** clears the warnings until a new one comes in. Each warning is listed once per load of the bundle, and a reload starts the list over. The same warnings go to the console, as [Logging](#logging) describes. Release builds don't show the tray.

## Bridge statistics

`stats` from `swiftui-svelte` counts the renderer's work. `live` is the number of element nodes that haven't been released yet, `commits` and `ops` count the batches and operations sent to the host, `bytes` is their total size, and `serializeMs` and `nativeMs` are the time spent encoding batches and the time spent inside the host's commit call. Read it to look for leaks and to compare performance between builds. `protocol` is the bridge protocol version the bundle was built with.

## Misspelled elements and attributes

While `vite build --watch` runs, or in a build with `--mode development`, the bundle also checks element and attribute names and reports a warning in the tray and in Xcode's console for any it doesn't recognize, such as `<txt> doesn't have an attribute named "paddng". Did you mean "padding"?`. Each name is reported once. An element name that isn't built in renders as a red "Unknown element" label, unless you registered a native component with that name. Release builds leave the checks out.

`svelte-check` catches most of these before you build, because every element and attribute is typed. Run it with the TypeScript preset from [Getting started](getting-started.md).

## Common problems

- **The screen is blank.** Check Xcode's console for an error from the bundle, and check that `app.js` is in the app target. If the bundle fails to load, throws before it mounts, or never mounts, the app shows a message in place of the view in every build.
- **A control snaps back.** Elements are controlled, so a `textfield` shows `value` and a `toggle` shows `checked`. Update your state in `oninput` or `onchange`, or use a component from `swiftui-svelte/components` with `bind:`.
- **`document` or `window.location` is undefined.** There's no page, so the DOM APIs aren't there. [Web APIs](web-apis.md) lists what is, and the ESLint preset reports the globals that are missing.
- **A list is slow to scroll.** Give each `{#each}` a key, and put long lists in a `list` or a lazy stack. [Performance](performance.md) has more.
- **The simulator is fast but the device is slow.** Devices run JavaScriptCore without its JIT compiler. To see device-like speed in the simulator, launch the app with the JIT turned off, as [Performance](performance.md) shows.
