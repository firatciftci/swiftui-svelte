import type { Plugin } from "vite";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { build } from "vite";
import { annotate } from "./locations.ts";
import {
  appAliases,
  loadLibrary,
  routesModule,
  routesModuleId,
  routesWatchPath,
  syncRoutes,
} from "./routes.ts";
import { fixSvelte } from "./svelte-fixes.ts";

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
  let entryId = "";
  let isSourceless = false;
  let isDevelopment = false;
  const version = String(Date.now());
  const source = (): string => path.resolve(root, path.dirname(entry));
  return {
    name: "swiftui-svelte",
    api: { sync: () => syncRoutes(root, source()) },
    config: (user, { mode }) => {
      isDevelopment = mode === "development" || user.build?.watch != null;
      isSourceless = !isDevelopment && user.build?.sourcemap == null;
      return {
        publicDir: false,
        resolve: {
          alias: [
            ...appAliases,
            { find: /^svelte-sonner$/, replacement: "swiftui-svelte/sonner" },
            {
              find: /^mode-watcher$/,
              replacement: "swiftui-svelte/mode-watcher",
            },
          ],
        },
        define: {
          __SWIFTUI_SVELTE_DEV__: JSON.stringify(isDevelopment),
          __SWIFTUI_SVELTE_VERSION__: JSON.stringify(version),
          "process.env.NODE_ENV": JSON.stringify(
            isDevelopment ? "development" : "production",
          ),
        },
        build: {
          target: "es2023",
          outDir: slash === -1 ? "." : outFile.slice(0, slash),
          emptyOutDir: false,
          minify: user.build?.minify ?? !isDevelopment,
          sourcemap: user.build?.sourcemap ?? (isDevelopment || "hidden"),
          lib: {
            entry,
            formats: ["iife"],
            name: "SvelteApp",
            fileName: () => name,
          },
        },
      };
    },
    transform: {
      order: "pre",
      handler(code, id) {
        if (id.split("?", 1)[0] === entryId)
          return {
            code: `import "swiftui-svelte/renderer";\n${code}`,
            map: null,
          };
        if (id.endsWith(".svelte"))
          return annotate(code, id, root, {
            stamps: isDevelopment && !id.includes("/node_modules/"),
          });
        return fixSvelte(code, id);
      },
    },
    generateBundle(_options, bundle) {
      if (!isSourceless) return;
      for (const file of Object.values(bundle)) {
        if (file.type !== "asset" || !file.fileName.endsWith(".map")) continue;
        const map = JSON.parse(String(file.source)) as Record<string, unknown>;
        delete map.sourcesContent;
        file.source = JSON.stringify(map);
      }
    },
    resolveId: (id) =>
      id === routesModuleId ? `\0${routesModuleId}` : undefined,
    load(id) {
      if (id !== `\0${routesModuleId}`) return loadLibrary(id);
      this.addWatchFile(routesWatchPath(source()));
      return routesModule(root, source());
    },
    configResolved(config) {
      ({ root } = config);
    },
    buildStart() {
      syncRoutes(root, source());
      if (!existsSync(path.resolve(root, entry))) {
        throw new Error(
          `swiftui(): there's no entry file at ${entry}. Pass the file that calls mountApp, such as swiftui({ entry: "src/main.ts", outFile }).`,
        );
      }
      entryId = realpathSync(path.resolve(root, entry));
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
      const routes = routesWatchPath(source());
      server.watcher.add(routes);
      server.watcher.on("all", (_event, file) => {
        if (file.startsWith(`${routes}${path.sep}`)) syncRoutes(root, source());
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
