import { svelte } from "@sveltejs/vite-plugin-svelte";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import process from "node:process";
import { build } from "vite";
import type { Sample } from "./driver.ts";
import { tailwind } from "../../src/tailwind/vite.ts";
import { swiftui } from "../../src/vite.ts";

export type { Sample } from "./driver.ts";

export const jsc =
  "/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc";

const root = path.resolve(import.meta.dirname, "../..");

async function bundle(): Promise<string> {
  const environment = process.env.NODE_ENV;
  process.env.NODE_ENV = "production";
  let result: Awaited<ReturnType<typeof build>>;
  try {
    result = await build({
      root,
      configFile: false,
      logLevel: "silent",
      mode: "production",
      plugins: [
        svelte(),
        tailwind({ css: "test/jsc/app.css", sources: ["test/jsc"] }),
        swiftui({ entry: "test/jsc/main.ts", outFile: "jsc/app.js" }),
      ],
      build: { write: false, sourcemap: false },
      resolve: { alias: { "swiftui-svelte": path.join(root, "src") } },
    });
  } finally {
    if (environment == null) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = environment;
  }
  const outputs = Array.isArray(result) ? result : [result];
  for (const output of outputs) {
    if (!("output" in output)) continue;
    for (const file of output.output)
      if (file.type === "chunk") return file.code;
  }
  throw new Error("The benchmark bundle has no JavaScript chunk.");
}

export async function benchmark({
  count = 1000,
  rounds = 5,
}: { count?: number; rounds?: number } = {}): Promise<Record<string, Sample>> {
  const directory = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-jsc-"));
  try {
    const file = path.join(directory, "app.js");
    writeFileSync(file, await bundle());
    const output = execFileSync(
      jsc,
      [
        "--useJIT=false",
        file,
        "-e",
        `print(JSON.stringify(__jscBench(${count}, ${rounds})))`,
      ],
      { encoding: "utf8", maxBuffer: 16 * 1024 * 1024 },
    );
    const last = output.trim().split("\n").at(-1) ?? "{}";
    return JSON.parse(last) as Record<string, Sample>;
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}
