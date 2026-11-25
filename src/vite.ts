import type { Plugin } from "vite";
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { build } from "vite";

export function swiftui({
  entry = "src/main.ts",
  outFile,
}: {
  entry?: string;
  outFile: string;
}): Plugin {
  if (!outFile.endsWith(".js")) {
    throw new Error(
      `swiftui(): outFile must be the path of a .js file, such as "ios/MyApp/Resources/app.js", not "${outFile}".`,
    );
  }
  const slash = outFile.lastIndexOf("/");
  const name = outFile.slice(slash + 1);
  let root = process.cwd();
  return {
    name: "swiftui-svelte",
    config: (user, { mode }) => {
      const isDevelopment = mode === "development" || user.build?.watch != null;
      return {
        publicDir: false,
        define: { __SWIFTUI_SVELTE_DEV__: JSON.stringify(isDevelopment) },
        build: {
          target: "es2023",
          outDir: slash === -1 ? "." : outFile.slice(0, slash),
          emptyOutDir: false,
          minify: user.build?.minify ?? !isDevelopment,
          sourcemap: user.build?.sourcemap ?? true,
          lib: {
            entry,
            formats: ["iife"],
            name: "SvelteApp",
            fileName: () => name,
          },
        },
      };
    },
    configResolved(config) {
      ({ root } = config);
    },
    buildStart() {
      if (!existsSync(path.resolve(root, entry))) {
        throw new Error(
          `swiftui(): there's no entry file at ${entry}. Pass the file that calls mountApp, such as swiftui({ entry: "src/main.ts", outFile }).`,
        );
      }
    },
    async configureServer(server) {
      const file = path.resolve(root, outFile);
      const files = new Map([
        [`/${name}`, file],
        [`/${name}.map`, `${file}.map`],
      ]);
      server.middlewares.use((request, response, next) => {
        const target = files.get(request.url?.split("?", 1)[0] ?? "");
        if (target == null || !existsSync(target)) {
          next();
          return;
        }
        const { size, mtimeMs } = statSync(target);
        const tag = `"${size}-${Math.round(mtimeMs)}"`;
        response.setHeader("Cache-Control", "no-cache");
        response.setHeader("ETag", tag);
        if (request.headers["if-none-match"] === tag) {
          response.statusCode = 304;
          response.end();
          return;
        }
        response.setHeader(
          "Content-Type",
          target.endsWith(".map") ? "application/json" : "text/javascript",
        );
        response.end(readFileSync(target));
      });
      const { inlineConfig } = server.config;
      const watcher = await build({
        ...inlineConfig,
        mode: "development",
        server: undefined,
        build: { ...inlineConfig.build, watch: {} },
      });
      server.httpServer?.once("close", () => {
        if ("close" in watcher) void watcher.close();
      });
    },
  };
}
