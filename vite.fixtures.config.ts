import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";
import { swiftui } from "./src/vite.ts";

export default defineConfig({
  logLevel: "warn",
  plugins: [
    svelte(),
    swiftui({
      entry: "test/native.ts",
      outFile: "Tests/SvelteSwiftUITests/Fixtures/app.js",
    }),
  ],
  build: { minify: true, sourcemap: false },
  resolve: {
    alias: { "swiftui-svelte": new URL("src", import.meta.url).pathname },
  },
});
