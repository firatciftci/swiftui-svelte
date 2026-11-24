import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [svelte()],
  publicDir: false,
  build: {
    target: "es2023",
    outDir: "ios/SvelteHost/Resources",
    emptyOutDir: false,
    minify: false,
    lib: {
      entry: "src/main.ts",
      formats: ["iife"],
      name: "SvelteApp",
      fileName: () => "app.js",
    },
  },
});
