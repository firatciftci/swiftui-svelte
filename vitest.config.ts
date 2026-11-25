import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [svelte()],
  define: { __SWIFTUI_SVELTE_DEV__: "true" },
  resolve: {
    alias: { "swiftui-svelte": new URL("src", import.meta.url).pathname },
    conditions: ["svelte-custom-renderer", "browser"],
  },
  test: {
    include: ["test/**/*.test.ts"],
    environment: "./test/environment.ts",
    setupFiles: ["test/setup.ts"],
    execArgv: ["--expose-gc"],
    coverage: { include: ["src/**/*.ts"], reporter: ["text", "lcov"] },
  },
});
