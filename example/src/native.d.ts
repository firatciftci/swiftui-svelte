import type { NativeElement } from "swiftui-svelte/elements";

declare module "svelte/elements" {
  interface SvelteHTMLElements {
    mapview: NativeElement<
      { latitude: number; longitude: number; span?: number; marker?: string },
      { regionchange: { latitude: number; longitude: number } }
    >;
  }
}

declare module "swiftui-svelte/native" {
  interface NativeModules {
    camera: {
      isAvailable: () => Promise<boolean>;
      takePhoto: () => Promise<string | null>;
    };
  }
}
