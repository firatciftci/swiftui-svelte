# Releasing to the App Store

An app built with swiftui-svelte is a regular SwiftUI app that carries one JavaScript file, so it goes through TestFlight and App Review like any other app. Check these items before you archive.

## Build the bundle for release

`vite build` writes a minified `app.js` and its `app.js.map`. The template's **Bundle the JavaScript** build phase runs `npm run build` for every Release build, so an archive always has a fresh bundle. If you set up the Xcode project yourself, add a Run Script phase before **Copy Bundle Resources** that runs `vite build`, or run it yourself before you archive. A bundle from `vite build --watch` or `--mode development` isn't minified and includes the checks for misspelled attributes, so don't ship one.

## Load the bundle from the app

Release builds should load `app.js` from the app bundle. The template's `MainApp.swift` reads the `SVELTE_SOURCE` environment variable and the bundle in your source tree only in Debug builds, and turns off `reloadsOnChange` in Release builds. If you load the bundle from the Vite dev server while you develop, put that code behind `#if DEBUG` the same way, so a Release build never points at your Mac.

Ship the JavaScript inside the app, and change it with app updates. App Review Guideline 2.5.2 says that apps "should be self-contained in their bundles, and may not read or write data outside the designated container area, nor may they download, install, or execute code which introduces or changes features or functionality of the app".

## Keep the versions in step

The bundle carries the version of the bridge protocol it was built for, and `SvelteView` shows a version mismatch screen instead of your app when the Swift package doesn't match. Release the npm package and the Swift package at the same version: pin `swiftui-svelte` to an exact version in `package.json`, and choose **Exact Version** for the SvelteSwiftUI package in Xcode, or update both at once.

## Privacy

The SvelteSwiftUI package includes a privacy manifest. It declares that the package reads and writes `UserDefaults`, which backs `localStorage` and `restorable`, and that it reads file modification dates, which it uses to notice a new bundle for live reload. Xcode adds the manifest to your app's privacy report when you archive. Your app still needs a manifest of its own for what your Swift code and your other dependencies do. Data that your JavaScript sends to a server, such as analytics, counts toward the privacy details you give in App Store Connect too.

The template's Info.plist sets `NSAllowsLocalNetworking` and `NSLocalNetworkUsageDescription`, so a Debug build can load the bundle from the dev server. A Release build doesn't connect to the local network, so iOS never asks the user for access. If you'd rather not ship the keys, move them into an Info.plist that only the Debug configuration uses. Add a usage description, such as `NSCameraUsageDescription`, for each permission that your native modules ask for.

## What changes in a Release build

- Safari's Web Inspector doesn't list the JavaScript context.
- Errors don't show the overlay. They print to the console with positions in your source, which `SvelteView` reads from `app.js.map`, and the app keeps the last screen that rendered. Use `<svelte:boundary>` to show your own fallback.
- The checks for misspelled elements and attributes are left out of the bundle.

`app.js.map` contains your source code. To keep it out of the app, set `build.sourcemap` to `false` in your Vite config, or leave the file out of the app target. Errors then show positions in `app.js` instead.

## Test on a device before you submit

Devices run JavaScriptCore without its JIT compiler, so a Release build on an iPhone is the closest you'll get to what users see. Scroll your longest lists, open your heaviest screens, and check the launch time. [Performance](performance.md) shows how to measure. Then upload a build to TestFlight and try it there, since TestFlight builds run exactly as the App Store version will.
