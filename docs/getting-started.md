# Getting started

The quickest start is a new app from the template:

```sh
npx swiftui-svelte create my-app
cd my-app
npm install
npm run build
open ios/MyApp.xcodeproj
```

The template has a Svelte app with TypeScript, ESLint, and the presets below, and an Xcode project that depends on the Swift package. A build phase in the Xcode project bundles the JavaScript for Release builds, and for any build that doesn't have a bundle yet. Run `npm run dev` while you work, and the app in the simulator reloads each time you save. Use `npm run serve` for an app on a device. It starts Vite's dev server.

To add swiftui-svelte to an app you already have, follow the steps below.

## 1. Set up the Svelte app

Install the package alongside Svelte and Vite:

```sh
npm install -D swiftui-svelte svelte vite @sveltejs/vite-plugin-svelte
```

Point the Svelte compiler at the renderer in `svelte.config.js`:

```js
export default {
  compilerOptions: {
    experimental: { customRenderer: "swiftui-svelte/renderer" },
  },
};
```

Add the Vite plugin, which bundles the app into the single file that the iOS app loads:

```ts
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";
import { swiftui } from "swiftui-svelte/vite";

export default defineConfig({
  plugins: [
    svelte(),
    swiftui({ entry: "src/main.ts", outFile: "ios/MyApp/Resources/app.js" }),
  ],
});
```

Register your root component in `src/main.ts`:

```ts
import { mountApp } from "swiftui-svelte";
import App from "./App.svelte";

mountApp(App);
```

Finally, add `"swiftui-svelte/elements"` to `compilerOptions.types` in `tsconfig.json`, so `svelte-check` can find the elements and their attributes. Run `vite build` to write `app.js`, minified, with `app.js.map` beside it. `vite build --watch` and `--mode development` skip the minification, so the code stays readable in Safari's Web Inspector. To choose for yourself, set `build.minify` in your Vite config.

The package also has presets for TypeScript and ESLint. To start from compiler options that match the iOS runtime, extend the TypeScript preset in `tsconfig.json`. It already includes the element types and Vite's `import.meta.env` types. `rootDirs` and the `.swiftui-svelte/types` entry let routes import their generated `./$types`, and they supply types for the `$app/*` modules:

```json
{
  "extends": "swiftui-svelte/tsconfig",
  "compilerOptions": { "rootDirs": [".", "./.swiftui-svelte/types"] },
  "include": ["src", ".swiftui-svelte/types"]
}
```

Run `swiftui-svelte sync` before `svelte-check`, as the template's `check` script does, so the generated types exist before the first build.

The ESLint preset reports browser globals that the iOS app doesn't have, such as `document`, `ResizeObserver`, and `XMLHttpRequest`, and says what to use instead. Add it to a flat config:

```js
import { swiftuiSvelte } from "swiftui-svelte/eslint";

export default [...swiftuiSvelte];
```

## 2. Show it in the iOS app

In Xcode, choose **File › Add Package Dependencies**, enter `https://github.com/firatciftci/swiftui-svelte`, and add the `SvelteSwiftUI` library to your app target. Add `app.js` to the app's resources, then show it with `SvelteView`:

```swift
import SvelteSwiftUI
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            SvelteView(source: Bundle.main.bundleURL.appending(path: "app.js"))
        }
    }
}
```

> [!TIP]
> For live reload, pass `reloadsOnChange: true` and, in the simulator, point `source` at the `app.js` in your source tree instead of the bundled copy. Then run `vite build --watch`, and the app reloads each time you save. [`SvelteHostApp.swift`](../example/ios/SvelteHost/SvelteHostApp.swift) in the example shows how.

To load the app from Vite's dev server instead, which also works on a device, run `vite --host` in place of `vite build --watch`. The `swiftui()` plugin then builds the bundle in watch mode and serves it from the dev server under the file name of `outFile`, with its source map. Point `SvelteView` at the Network address that Vite prints, and the app reloads each time you save:

```swift
SvelteView(source: URL(string: "http://192.168.1.20:5173/app.js")!, reloadsOnChange: true)
```

The iPhone needs to be on the same network as your Mac. For a Debug build to connect, add two keys to its Info.plist: `NSAppTransportSecurity` with `NSAllowsLocalNetworking` set to `true`, which allows plain HTTP to your Mac, and `NSLocalNetworkUsageDescription`, the reason iOS shows when it asks the user for access to the local network. The plugin still writes `outFile`, so the simulator can keep loading the file directly.
