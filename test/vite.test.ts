import type { IncomingMessage } from "node:http";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { mkdtempSync } from "node:fs";
import { get } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { gzipSync } from "node:zlib";
import { build, createServer } from "vite";
import { describe, expect, it } from "vitest";
import { swiftui } from "swiftui-svelte/vite";

const budget = { minified: 180_000, gzipped: 55_000 };

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
