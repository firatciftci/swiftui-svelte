import { paraglideVitePlugin } from "@inlang/paraglide-js";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { mdsvex } from "mdsvex";
import path from "node:path";
import { defineConfig } from "vitest/config";
import {
  appAliases,
  loadLibrary,
  routesModule,
  routesModuleId,
} from "./src/routes.ts";
import { fixSvelte } from "./src/svelte-fixes.ts";

const source = path.resolve("test/router/src");
const src = new URL("src", import.meta.url).pathname;

export default defineConfig({
  plugins: [
    paraglideVitePlugin({
      project: "./example/project.inlang",
      outdir: "./example/src/paraglide",
      strategy: ["preferredLanguage", "baseLocale"],
    }),
    mdsvex({ extensions: [".md"] }),
    svelte({ extensions: [".svelte", ".md"] }),
    { name: "svelte-fixes", transform: (code, id) => fixSvelte(code, id) },
    {
      name: "swiftui-svelte-routes",
      resolveId: (id) =>
        id === routesModuleId ? `\0${routesModuleId}` : undefined,
      load: (id) =>
        id === `\0${routesModuleId}`
          ? routesModule(import.meta.dirname, source)
          : loadLibrary(id),
    },
  ],
  define: {
    __SWIFTUI_SVELTE_DEV__: "true",
    __SWIFTUI_SVELTE_VERSION__: JSON.stringify("test"),
  },
  resolve: {
    alias: [...appAliases, { find: "swiftui-svelte", replacement: src }],
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
