import { paraglideVitePlugin } from "@inlang/paraglide-js";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";
import { swiftui } from "./src/vite.ts";

export default defineConfig({
  plugins: [
    paraglideVitePlugin({
      project: "./example/project.inlang",
      outdir: "./example/src/paraglide",
      strategy: ["preferredLanguage", "baseLocale"],
    }),
    svelte(),
    swiftui({
      entry: "example/src/main.ts",
      outFile: "example/ios/SvelteHost/Resources/app.js",
    }),
  ],
  resolve: {
    alias: { "swiftui-svelte": new URL("src", import.meta.url).pathname },
  },
});
