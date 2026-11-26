# Native modules and components

## Calling Swift from JavaScript

Register Swift functions in a `NativeModule` and pass it to the view. Arguments arrive through `Decodable`, and the return value goes back to JavaScript through `Encodable`:

```swift
struct Forecast: Codable {
    let high: Double
    let low: Double
}

let weather = NativeModule("weather")
    .function("forecast") { (city: String, days: Int) async throws -> Array<Forecast> in
        try await WeatherService.shared.forecast(for: city, days: days)
    }

SvelteView(source: bundle, modules: [weather])
```

In JavaScript, each function becomes an async function:

```ts
import { nativeModule } from "swiftui-svelte/native";

const weather = nativeModule("weather");
const days = await weather.forecast("Chicago", 3);
```

To type the module, declare its functions and events:

```ts
declare module "swiftui-svelte/native" {
  interface NativeModules {
    weather: {
      forecast: (
        city: string,
        days: number,
      ) => Promise<Array<{ high: number; low: number }>>;
    };
  }
  interface NativeEvents {
    weather: { alert: { message: string } };
  }
}
```

- A function takes up to two arguments. A missing argument decodes as `nil`, so make it optional when JavaScript can leave it out.
- When the function throws `NativeModuleError(code:message:)`, the promise rejects with a `NativeError` that has the same `code` and `message`. Other errors reject with the code `native`. Arguments that don't decode reject with `invalidArguments`, and calls to functions that don't exist reject with `unknownFunction`.
- `runtime.emit("alert", from: "weather", Alert(message: "Storm"))` sends an event, and `weather.on("alert", (alert) => …)` receives it. `on` returns a function that unsubscribes.
- After a reload, the runtime drops the replies to calls that the old bundle made.

## Built-in modules

`swiftui-svelte/native` also exports modules that most apps need:

| Export          | What it does                                                                                                                                                                                    |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `haptics`       | `impact({ style, intensity })`, `notification(type)`, and `selection()` play haptics                                                                                                            |
| `clipboard`     | `readText()`, `writeText(text)`, and `hasText()`. iOS asks the user before an app reads text that another app copied                                                                            |
| `share`         | `share({ text, url, subject })` opens the share sheet and resolves with `{ completed }`                                                                                                         |
| `links`         | `open(url)` opens a URL in the app that handles it, and `canOpen(url)` checks whether an app can                                                                                                |
| `secureStorage` | `get(key)`, `set(key, value)`, and `delete(key)` keep strings in the Keychain                                                                                                                   |
| `files`         | `readText(path)`, `writeText(path, text)`, `delete(path)`, `exists(path)`, and `list(path)` work with files in the app's Application Support folder. Paths are relative, and `..` isn't allowed |

For `canOpen` to see a custom URL scheme, list the scheme under `LSApplicationQueriesSchemes` in Info.plist.

## Native components

To show a SwiftUI view that the library doesn't include, such as a map, register a `NativeComponent` under an element name:

```swift
let map = NativeComponent("mapview") { element in
    MapElement(element: element)
}

SvelteView(source: bundle, components: [map])
```

`element` reads attributes with `string`, `number`, `bool`, `value`, and `decode(_:_:)`. It renders the element's children with `children`, or one named child with `slot(name)`, and it sends events to `on<event>` handlers with `send`. The view updates when an attribute changes, and modifiers like `padding` and `frame` still apply. To type the element in Svelte, add it to `SvelteHTMLElements` with the `NativeElement` helper:

```ts
import type { NativeElement } from "swiftui-svelte/elements";

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    mapview: NativeElement<
      { latitude: number; longitude: number },
      { regionchange: { latitude: number; longitude: number } }
    >;
  }
}
```

A native component can also own names that the built-in modifiers use. Pass the names in `attributes` and `events` when you create it:

```swift
let probe = NativeComponent("probe", attributes: ["color"], events: ["hover"]) { element in
    ProbeElement(element: element)
}
```

For this element, the library drops those names from its modifier chain. A `color` attribute goes to your view and not to the `foregroundStyle` modifier, and a `hover` event goes to your `onhover` handler and not to the library's pointer handler. Every other attribute and event still works as usual. In Svelte, type the element with the same names, and the `NativeElement` helper removes the matching built-in modifiers from its type:

```ts
import type { NativeElement } from "swiftui-svelte/elements";

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    probe: NativeElement<{ color: string }, { hover: { phase: string } }>;
  }
}
```

The example app's `mapview` shows a complete component built on MapKit.
