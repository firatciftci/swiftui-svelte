import type { NativeElement } from "swiftui-svelte/elements";

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    weathermap: NativeElement<
      { latitude: number; longitude: number },
      { regionchange: { latitude: number; longitude: number } }
    >;
  }
}
