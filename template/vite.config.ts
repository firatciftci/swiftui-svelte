import { svelte } from "@sveltejs/vite-plugin-svelte";
import { swiftui } from "swiftui-svelte/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    svelte(),
    swiftui({
      entry: "src/main.ts",
      outFile: "ios/__APP_NAME__/JavaScript/app.js",
    }),
  ],
});
