import type { IncomingMessage } from "node:http";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { get } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { gzipSync } from "node:zlib";
import { build, createServer } from "vite";
import { describe, expect, it } from "vitest";
import { fixSvelte } from "swiftui-svelte/svelte-fixes";
import { swiftui } from "swiftui-svelte/vite";
import type { State } from "../src/tailwind/runtime.ts";
import { buildClassTable } from "../src/tailwind/build.ts";
import { arithmetic, resolveClasses } from "../src/tailwind/runtime.ts";
import { parseColor } from "../src/tailwind/values.ts";
import { tailwind } from "../src/tailwind/vite.ts";

const budget = { minified: 191_000, gzipped: 59_250 };

async function bundle(
  options: { mode?: string; entry?: string } = {},
): Promise<{ code: string; files: Array<string> }> {
  const result = await build({
    configFile: false,
    logLevel: "silent",
    mode: options.mode ?? "production",
    plugins: [
      svelte(),
      swiftui({
        entry: options.entry ?? "test/size/main.ts",
        outFile: "size/app.js",
      }),
    ],
    build: { write: false },
    resolve: {
      alias: { "swiftui-svelte": path.resolve(import.meta.dirname, "../src") },
    },
  });
  const outputs = Array.isArray(result) ? result : [result];
  let code = "";
  const files = new Array<string>();
  for (const output of outputs) {
    if (!("output" in output)) continue;
    for (const file of output.output) {
      files.push(file.fileName);
      if (file.type === "chunk") ({ code } = file);
    }
  }
  return { code, files };
}

async function request(
  url: string,
  headers: Record<string, string> = {},
): Promise<{ status: number; tag: string; type: string; body: string }> {
  const response = await new Promise<IncomingMessage>((resolve, reject) => {
    get(url, { headers }, resolve).on("error", reject);
  });
  let body = "";
  for await (const chunk of response) body += String(chunk);
  return {
    status: response.statusCode ?? 0,
    tag: response.headers.etag ?? "",
    type: response.headers["content-type"] ?? "",
    body,
  };
}

async function served(
  url: string,
): Promise<Awaited<ReturnType<typeof request>>> {
  for (let attempt = 0; attempt < 100; attempt++) {
    const response = await request(url);
    if (response.status === 200) return response;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`${url} never loaded.`);
}

describe("the Vite plugin", () => {
  it("keeps the renderer and the host polyfills within budget", async () => {
    const { code } = await bundle();
    const size = { minified: code.length, gzipped: gzipSync(code).length };
    expect(size.minified).toBeGreaterThan(budget.minified / 2);
    expect(size.minified).toBeLessThanOrEqual(budget.minified);
    expect(size.gzipped).toBeLessThanOrEqual(budget.gzipped);
  }, 60_000);

  it("minifies production builds and leaves out the development checks", async () => {
    const { code, files } = await bundle();
    expect(files.toSorted((a, b) => a.localeCompare(b))).toEqual([
      "app.js",
      "app.js.map",
    ]);
    expect(code.split("\n").length).toBeLessThan(50);
    expect(code).not.toContain("doesn't have an attribute");
  }, 60_000);

  it("keeps development builds readable and checks names", async () => {
    const { code } = await bundle({ mode: "development" });
    expect(code.split("\n").length).toBeGreaterThan(1000);
    expect(code).toContain("doesn't have an attribute");
  }, 60_000);

  it("replaces process.env.NODE_ENV, which JavaScriptCore doesn't define", async () => {
    const entry = path.join(
      mkdtempSync(path.join(tmpdir(), "node-env-")),
      "main.ts",
    );
    writeFileSync(entry, "export const mode = process.env.NODE_ENV;\n");
    const production = await bundle({ entry });
    expect(production.code).not.toContain("process.env");
    expect(production.code).toMatch(/["'`]production["'`]/);
    const development = await bundle({ entry, mode: "development" });
    expect(development.code).not.toContain("process.env");
    expect(development.code).toMatch(/["'`]development["'`]/);
  });

  it("injects the class table only into modules that import mountApp", () => {
    const { transform } = tailwind({ css: "app.css" });
    if (typeof transform !== "function")
      throw new TypeError("Expected a transform hook");
    const inject = (code: string): unknown =>
      Reflect.apply(transform, {}, [code, "/app/src/main.ts"]);
    expect(
      inject('import { mountApp } from "swiftui-svelte";\nmountApp(App);\n'),
    ).not.toBeNull();
    expect(
      inject(
        "export function mountApp(root) {}\nthrow new Error(`Pass it to mountApp().`);\n",
      ),
    ).toBeNull();
  });

  it("installs the web APIs before any module of the app runs", async () => {
    const entry = path.join(
      mkdtempSync(path.join(tmpdir(), "entry-order-")),
      "main.ts",
    );
    writeFileSync(
      entry,
      'import { SvelteURLSearchParams } from "svelte/reactivity";\nexport const Params = SvelteURLSearchParams;\n',
    );
    const { code } = await bundle({ entry, mode: "development" });
    const install = code.indexOf("installWebAPIs();");
    expect(install).toBeGreaterThan(-1);
    expect(install).toBeLessThan(code.indexOf("extends URLSearchParams"));
  });

  it("bundles the linear keyed each fix into Svelte's each block", async () => {
    const { code } = await bundle({
      mode: "development",
      entry: "test/native.ts",
    });
    expect(code).toContain("new Map()).set(current, stashed.length)");
    expect(code).not.toContain("new Set()).add(current)");
  }, 60_000);

  it("returns the patched each block without a source map", () => {
    const file = path.resolve(
      "node_modules/svelte/src/internal/client/dom/blocks/each.js",
    );
    const fixed = fixSvelte(readFileSync(file, "utf8"), file);
    expect(fixed?.map).toBeNull();
    expect(fixed?.code).toContain("new Map()).set(current, stashed.length)");
  });

  it("leaves other files and changed each blocks alone", () => {
    const each = "/node_modules/svelte/src/internal/client/dom/blocks/each.js";
    expect(
      fixSvelte("(seen ??= new Set()).add(current);", "/src/each.js"),
    ).toBeNull();
    expect(fixSvelte("export {};", each)).toBeNull();
    expect(fixSvelte("(seen ??= new Set()).add(current);", each)).toBeNull();
  });

  it("explains a missing entry and an outFile that isn't JavaScript", async () => {
    await expect(bundle({ entry: "test/size/missing.ts" })).rejects.toThrow(
      "swiftui(): there's no entry file at test/size/missing.ts.",
    );
    expect(() => swiftui({ outFile: "ios/MyApp/Resources" })).toThrow(
      'swiftui(): outFile must be the path of a .js file, such as "ios/MyApp/Resources/app.js", not "ios/MyApp/Resources".',
    );
  }, 60_000);

  it("builds in watch mode and serves the bundle from the dev server", async () => {
    const outDir = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-"));
    const server = await createServer({
      configFile: false,
      logLevel: "silent",
      plugins: [
        svelte(),
        swiftui({ entry: "test/size/main.ts", outFile: `${outDir}/app.js` }),
      ],
      resolve: {
        alias: {
          "swiftui-svelte": path.resolve(import.meta.dirname, "../src"),
        },
      },
      server: { port: 0 },
    });
    await server.listen();
    try {
      const address = server.httpServer?.address();
      const port = typeof address === "object" ? address?.port : null;
      const base = `http://localhost:${port}`;
      const bundle = await served(`${base}/app.js`);
      expect(bundle.type).toBe("text/javascript");
      expect(bundle.body).toContain("doesn't have an attribute");
      const unchanged = await request(`${base}/app.js`, {
        "if-none-match": bundle.tag,
      });
      expect(unchanged.status).toBe(304);
      const map = await served(`${base}/app.js.map`);
      expect(map.type).toBe("application/json");
      expect(JSON.parse(map.body)).toHaveProperty("mappings");
    } finally {
      await server.close();
    }
  }, 60_000);
});

describe("tailwind class table", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-tailwind-"));
  writeFileSync(
    path.join(dir, "app.css"),
    '@import "tailwindcss";\n@custom-variant dark (&:where(.dark, .dark *));\n',
  );
  writeFileSync(
    path.join(dir, "App.svelte"),
    '<vstack class="p-4 bg-white dark:bg-black md:p-2 transition-opacity grid-cols-2"></vstack>\n',
  );

  it("maps utilities to attributes, conditions, and breakpoints", async () => {
    const { table, warnings, files } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
    });
    expect(table.tokens["p-4"]?.[0]?.attrs).toMatchObject({
      padding: { top: 16, leading: 16, bottom: 16, trailing: 16 },
    });
    expect(table.tokens["bg-white"]?.[0]?.attrs).toEqual({
      background: "#ffffff",
    });
    expect(table.tokens["dark:bg-black"]?.[0]).toMatchObject({
      when: ["dark"],
    });
    expect(table.tokens["md:p-2"]?.[0]).toMatchObject({ when: [">=768"] });
    expect(table.breakpoints).toContain(768);
    expect(files).toContain(dir);
    expect(warnings).toEqual([
      expect.stringMatching(
        /^Tailwind class "grid-cols-2" in .*App\.svelte isn't supported by swiftui-svelte: .+\.$/,
      ),
    ]);
  }, 60_000);
});

describe("native Tailwind utilities", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-native-"));
  writeFileSync(
    path.join(dir, "app.css"),
    `@import "tailwindcss";
@import "${path.resolve("src/tailwind/theme.css")}";
@utility hairline {
  border-width: hairlineWidth();
}
@utility system-label {
  color: platformColor(label);
}
@utility bad-system-color {
  color: platformColor(systemBlue);
}
`,
  );
  writeFileSync(
    path.join(dir, "Native.svelte"),
    '<vstack class="web:p-4 ios:p-2 android:p-6 native:gap-2 tv:p-8 contrast-more:p-1 portrait:p-3 landscape:p-5 rtl:p-7 ltr:p-9 pb-safe-offset-4 pt-safe pb-safe-or-[2px] h-screen-safe hairline corner-rounded tint-red-500 elevation-md ripple-blue-500 system-label bad-system-color"></vstack>\n',
  );
  const built = buildClassTable({
    root: process.cwd(),
    css: path.join(dir, "app.css"),
    sources: [dir],
    fonts: {},
  });

  it("reads platform, idiom, contrast, orientation, and direction conditions", async () => {
    const { table } = await built;
    expect(table.tokens["web:p-4"]?.[0]?.when).toEqual(["web"]);
    expect(table.tokens["ios:p-2"]?.[0]?.when).toEqual(["platform:ios"]);
    expect(table.tokens["android:p-6"]?.[0]?.when).toEqual([
      "platform:android",
    ]);
    expect(table.tokens["native:gap-2"]?.[0]?.when).toEqual(["native"]);
    expect(table.tokens["tv:p-8"]?.[0]?.when).toEqual(["idiom:tv"]);
    expect(table.tokens["contrast-more:p-1"]?.[0]?.when).toEqual([
      "contrast:more",
    ]);
    expect(table.tokens["portrait:p-3"]?.[0]?.when).toEqual([
      "orientation:portrait",
    ]);
    expect(table.tokens["landscape:p-5"]?.[0]?.when).toEqual([
      "orientation:landscape",
    ]);
    expect(table.tokens["rtl:p-7"]?.[0]?.when).toEqual(["rtl"]);
    expect(table.tokens["ltr:p-9"]?.[0]?.when).toEqual(["ltr"]);
  }, 60_000);

  it("keeps device-dependent values for the host to measure", async () => {
    const { table } = await built;
    expect(table.tokens["pb-safe-offset-4"]?.[0]).toMatchObject({
      dynamic: true,
      attrs: {
        padding: {
          bottom: { op: "+", args: [{ op: "insetBottom", args: [] }, 16] },
        },
      },
    });
    expect(table.tokens["pb-safe-or-[2px]"]?.[0]).toMatchObject({
      attrs: {
        padding: {
          bottom: { op: "max", args: [{ op: "insetBottom", args: [] }, 2] },
        },
      },
    });
    expect(table.tokens["pt-safe"]?.[0]).toMatchObject({
      attrs: { padding: { top: { op: "insetTop", args: [] } } },
    });
    expect(table.tokens["h-screen-safe"]?.[0]?.attrs).toEqual({
      height: "infinity",
      boxsizing: "border-box",
    });
    expect(table.tokens.hairline?.[0]).toMatchObject({
      dynamic: true,
      attrs: { $borderWidth: { top: { op: "hairlineWidth", args: [] } } },
    });
  }, 60_000);

  it("maps corners, tint, and Android-only attributes", async () => {
    const { table, warnings } = await built;
    expect(table.tokens["corner-rounded"]?.[0]?.attrs).toEqual({
      cornerstyle: "circular",
    });
    expect(table.tokens["tint-red-500"]?.[0]?.attrs).toEqual({
      tint: "#fb2c36",
    });
    expect(table.tokens["elevation-md"]?.[0]).toMatchObject({
      when: ["platform:android"],
      attrs: { elevation: 6 },
    });
    expect(table.tokens["ripple-blue-500"]?.[0]).toMatchObject({
      when: ["platform:android"],
      attrs: { ripple: { color: "#2b7fff" } },
    });
    expect(warnings).toEqual([
      expect.stringMatching(
        /^Tailwind class "bad-system-color" in .*Native\.svelte isn't supported by swiftui-svelte: platformColor\(systemBlue\) isn't a system color this library supports\.$/,
      ),
    ]);
  }, 60_000);
});

describe("tailwind layout, lengths, and containers", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-layout-"));
  writeFileSync(
    path.join(dir, "app.css"),
    `@import "tailwindcss";
@import "${path.resolve("src/tailwind/theme.css")}";
@custom-variant md (@container (width >= 48rem));
@theme {
  --text-sm: calc(0.875rem * clamp(0.8, fontScale(), 2));
  --text-sm--line-height: calc(1.25 / 0.875);
  --font-brand: "Avenir", sans-serif;
}
`,
  );
  writeFileSync(
    path.join(dir, "Layout.svelte"),
    '<vstack class="@container mx-auto -mt-2 mb-[env(safe-area-inset-bottom)] grid grid-cols-1 justify-items-center justify-center border-t border-x-red-500 border-b-0 focus:outline-none focus-visible:ring-2 md:p-2 @sm:p-4 @max-xs:min-w-88 justify-between decoration-2 text-balance text-pretty text-sm w-[50vw] w-[calc(10px*2)] gap-[min(4px,1vw)] rounded-[roundToNearestPixel(10px)] content-start table-fixed border-collapse ring-2 ring-red-500 drop-shadow-md"></vstack>\n<hstack class="@container/side flex-row grid-flow-col"></hstack>\n<vstack class="flex flex-col gap-2"></vstack>\n<hstack class="grid gap-1"></hstack>\n<vstack class="w-40 border-2 h-full"></vstack>\n<txt class="max-w-3xl max-w-full max-w-none text-sm leading-[normal]"></txt>\n',
  );
  const base: State = {
    dark: false,
    width: 800,
    height: 600,
    reduceMotion: false,
    rtl: false,
    disabled: false,
    platform: "unknown",
    idiom: "phone",
    increaseContrast: false,
    insets: { top: 0, right: 0, bottom: 0, left: 0 },
    pixelRatio: 2,
    fontScale: 1,
    containers: {},
  };

  it("maps margins, stack layout, borders, and focus states", async () => {
    const { table, warnings } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
    });
    expect(table.tokens["mx-auto"]?.[0]?.attrs).toEqual({
      margin: { leading: "auto", trailing: "auto" },
    });
    expect(table.tokens["-mt-2"]?.[0]?.attrs).toEqual({ margin: { top: -8 } });
    expect(table.tokens.grid?.[0]).toMatchObject({
      attrs: { css: true },
      only: ["vstack", "lazyvstack", "hstack", "lazyhstack"],
    });
    expect(table.tokens["grid-flow-col"]?.[0]?.only).toEqual([
      "hstack",
      "lazyhstack",
    ]);
    expect(table.tokens["justify-items-center"]?.[0]).toMatchObject({
      attrs: { alignment: "center" },
      only: ["vstack", "lazyvstack"],
    });
    expect(table.tokens["justify-center"]?.[0]).toMatchObject({
      attrs: { framealignment: "center" },
      only: ["vstack", "lazyvstack"],
    });
    expect(table.tokens["border-t"]?.[1]?.attrs).toEqual({
      $borderWidth: { top: 1 },
    });
    expect(table.tokens["border-x-red-500"]?.[0]?.attrs).toEqual({
      $borderColor: "#fb2c36",
    });
    expect(
      table.tokens["focus:outline-none"]?.map((rule) => rule.attrs),
    ).toEqual([{}]);
    expect(
      table.tokens["focus-visible:ring-2"]?.map((rule) => rule.attrs),
    ).toEqual([{}]);
    expect(table.tokens["content-start"]?.[0]?.attrs).toEqual({});
    expect(table.tokens["table-fixed"]?.[0]?.attrs).toEqual({});
    expect(table.tokens["border-collapse"]?.[0]?.attrs).toEqual({});
    expect(warnings).toEqual([
      expect.stringMatching(
        /^Tailwind class "justify-between" .+ distribution/,
      ),
      expect.stringMatching(/^Tailwind class "decoration-2" .+/),
    ]);
  }, 60_000);

  it("compiles container queries to container conditions, not window widths", async () => {
    const { table } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
      ignore: ["decoration-2"],
    });
    expect(table.tokens["@container"]?.[0]?.attrs).toEqual({ container: "" });
    expect(table.tokens["@container/side"]?.at(-1)?.attrs).toEqual({
      container: "side",
    });
    expect(table.tokens["@sm:p-4"]?.[0]?.when).toEqual(["container::>=384"]);
    expect(table.tokens["@max-xs:min-w-88"]?.[0]?.when).toEqual([
      "container::<320",
    ]);
    expect(table.tokens["md:p-2"]?.[0]?.when).toEqual(["container::>=768"]);
    expect(table.breakpoints).not.toContain(320);
    expect(table.tokens["decoration-2"]?.map((rule) => rule.attrs)).toEqual([
      {},
    ]);
  }, 60_000);

  it("sets the axis of a CSS stack from its display and flex direction", async () => {
    const { table } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
    });
    expect(resolveClasses(table, "hstack", "grid gap-1", base).attrs).toEqual({
      css: true,
      axis: "vertical",
      spacing: 4,
    });
    expect(resolveClasses(table, "vstack", "flex", base).attrs).toEqual({
      css: true,
      axis: "horizontal",
    });
    expect(
      resolveClasses(table, "vstack", "flex flex-col gap-2", base).attrs,
    ).toEqual({ css: true, axis: "vertical", spacing: 8 });
    expect(
      resolveClasses(table, "hstack", "flex flex-col", base).attrs,
    ).toEqual({ css: true, axis: "horizontal" });
  }, 60_000);

  it("sizes with border-box and draws rings and shadows without layout space", async () => {
    const { table, warnings } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
    });
    expect(
      resolveClasses(table, "vstack", "w-40 border-2", base).attrs,
    ).toMatchObject({
      width: 160,
      boxsizing: "border-box",
      border: { width: { top: 2, leading: 2, bottom: 2, trailing: 2 } },
    });
    expect(resolveClasses(table, "vstack", "h-full", base).attrs).toEqual({
      height: "infinity",
      boxsizing: "border-box",
    });
    expect(
      resolveClasses(table, "vstack", "ring-2 ring-red-500", base).attrs,
    ).toEqual({ ring: { width: 2, color: "#fb2c36" } });
    expect(
      resolveClasses(table, "txt", "max-w-3xl max-w-full", base).attrs,
    ).toEqual({ boxsizing: "border-box" });
    expect(resolveClasses(table, "txt", "max-w-none", base).attrs).toEqual({});
    expect(
      resolveClasses(table, "txt", "text-sm leading-[normal]", base).attrs,
    ).toEqual({ size: 14 });
    expect(resolveClasses(table, "vstack", "ring-2", base).attrs).toEqual({
      ring: { width: 2 },
    });
    expect(
      resolveClasses(table, "vstack", "drop-shadow-md", base).attrs,
    ).toMatchObject({ shadow: { radius: 3, y: 3 } });
    expect(warnings).toEqual([
      expect.stringMatching(
        /^Tailwind class "justify-between" .+ distribution/,
      ),
      expect.stringMatching(/^Tailwind class "decoration-2" .+/),
    ]);
  }, 60_000);

  it("keeps static lengths static and marks runtime expressions dynamic", async () => {
    const { table } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
      ignore: [],
    });
    expect(table.tokens["w-[calc(10px*2)]"]?.map((rule) => rule.attrs)).toEqual(
      [{ width: 20, boxsizing: "border-box" }],
    );
    expect(table.tokens["w-[50vw]"]?.[0]).toMatchObject({
      dynamic: true,
      attrs: {
        width: { op: "*", args: [0.5, { op: "viewportWidth", args: [] }] },
      },
    });
    expect(table.tokens["text-sm"]?.at(-1)).toMatchObject({
      dynamic: true,
      attrs: { linebox: { op: "*" } },
    });
    expect(
      table.tokens["rounded-[roundToNearestPixel(10px)]"]?.[0]?.attrs,
    ).toEqual({ radius: { op: "roundToNearestPixel", args: [10] } });
  }, 60_000);

  it("resolves expressions, container conditions, and text balance at runtime", async () => {
    const { table } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
      ignore: [],
    });
    const scaled = resolveClasses(table, "txt", "text-sm", {
      ...base,
      fontScale: 2,
    });
    expect(scaled.attrs.size).toBe(28);
    expect(scaled.attrs.linebox as number).toBeCloseTo(40);
    const fixed = resolveClasses(table, "txt", "text-sm", base);
    expect(fixed.attrs.size).toBe(14);
    expect(fixed.attrs.linebox as number).toBeCloseTo(20);
    expect(
      resolveClasses(table, "vstack", "@sm:p-4", {
        ...base,
        containers: { "": 500 },
      }).attrs,
    ).toEqual({ padding: { top: 16, leading: 16, bottom: 16, trailing: 16 } });
    expect(
      resolveClasses(table, "vstack", "@sm:p-4", {
        ...base,
        containers: { "": 300 },
      }).attrs,
    ).toEqual({});
    expect(resolveClasses(table, "txt", "text-balance", base).attrs).toEqual({
      balanced: true,
    });
    expect(resolveClasses(table, "txt", "text-pretty", base).attrs).toEqual({});
  }, 60_000);

  it("turns an ignored class into a no-op at runtime, even when it has a mapping", async () => {
    const { table, warnings } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: {},
      ignore: ["@sm:p-*"],
    });
    const resolved = resolveClasses(table, "vstack", "@sm:p-4", {
      ...base,
      containers: { "": 500 },
    });
    expect(resolved.attrs).toEqual({});
    expect(resolved.unmatched).toEqual([]);
    expect(warnings.some((warning) => warning.includes("@sm:p-4"))).toBe(false);
  }, 60_000);
});

describe("tailwind font families", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-fonts-"));
  writeFileSync(
    path.join(dir, "app.css"),
    `@import "tailwindcss";
@import "${path.resolve("src/tailwind/theme.css")}";
@theme {
  --font-brand: "Avenir", sans-serif;
}
`,
  );
  writeFileSync(
    path.join(dir, "Fonts.svelte"),
    '<txt class="font-brand"></txt>\n',
  );

  it("maps a theme font by its first family name", async () => {
    const { table, warnings } = await buildClassTable({
      root: process.cwd(),
      css: path.join(dir, "app.css"),
      sources: [dir],
      fonts: { Avenir: "Avenir-Medium" },
    });
    expect(table.tokens["font-brand"]?.[0]?.attrs).toEqual({
      fontname: "Avenir-Medium",
    });
    expect(warnings).toEqual([]);
  }, 60_000);
});

describe("tailwind value functions", () => {
  it("returns the minimum of clamp() when its bounds are inverted, as CSS does", () => {
    expect(arithmetic("clamp", [16, 10, 4])).toBe(16);
    expect(arithmetic("clamp", [0, 10, 4])).toBe(4);
    expect(arithmetic("clamp", [0, 2, 4])).toBe(2);
  });

  it("scales the alpha of a color-mix whose weights sum to less than 100%", () => {
    expect(
      parseColor("color-mix(in srgb, #ff0000 30%, #0000ff 30%)"),
    ).toMatchObject({ a: 0.6 });
    expect(parseColor("color-mix(in srgb, #ff0000, #0000ff)")).toMatchObject({
      a: 1,
    });
  });
});
