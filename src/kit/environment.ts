declare const __SWIFTUI_SVELTE_DEV__: boolean | undefined;
declare const __SWIFTUI_SVELTE_VERSION__: string | undefined;

export const browser = true;
export const dev = __SWIFTUI_SVELTE_DEV__ === true;
export const building = false;
export const version = __SWIFTUI_SVELTE_VERSION__ ?? "0";
