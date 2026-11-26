import { createStorage } from "swiftui-svelte/web/storage";
import { installBridge } from "./bridge.ts";

installBridge();
Object.assign(globalThis, { localStorage: createStorage([]) });
