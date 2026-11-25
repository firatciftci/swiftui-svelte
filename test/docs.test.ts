import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { compile } from "svelte/compiler";
import { describe, expect, it } from "vitest";

const root = path.resolve(import.meta.dirname, "..");
const pages = [
  "README.md",
  ...readdirSync(path.join(root, "docs"))
    .filter((name) => name.endsWith(".md") && name !== "reference.md")
    .map((name) => `docs/${name}`),
];
const snippets: Array<{ name: string; source: string }> = [];
for (const page of pages) {
  const text = readFileSync(path.join(root, page), "utf8");
  for (const match of text.matchAll(/```svelte\n([\s\S]*?)```/g))
    snippets.push({
      name: `${page} #${snippets.filter((snippet) => snippet.name.startsWith(page)).length + 1}`,
      source: match[1] ?? "",
    });
}

describe("docs", () => {
  it("has Svelte snippets to check", () => {
    expect(snippets.length).toBeGreaterThan(20);
  });

  it.each(snippets)("compiles $name", ({ name, source }) => {
    expect(() =>
      compile(source, {
        filename: `${name.replaceAll(/\W/g, "-")}.svelte`,
        experimental: { customRenderer: "swiftui-svelte/renderer" },
      }),
    ).not.toThrow();
  });
});
