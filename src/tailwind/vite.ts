import type { Plugin } from "vite";

export type TailwindOptions = {
  css: string;
  sources?: Array<string>;
  fonts?: Record<string, string>;
};

const ID = "virtual:swiftui-svelte/tailwind";
const RESOLVED_ID = `\0${ID}`;

export function tailwind({
  css,
  sources = ["src"],
  fonts = {},
}: TailwindOptions): Plugin {
  let root = "";
  return {
    name: "swiftui-svelte:tailwind",
    enforce: "pre",
    configResolved(config) {
      ({ root } = config);
    },
    resolveId(source) {
      return source === ID ? RESOLVED_ID : null;
    },
    async load(id) {
      if (id !== RESOLVED_ID) return null;
      const { buildClassTable } = await import("./build.ts");
      const { table, warnings, files } = await buildClassTable({
        root,
        css,
        sources,
        fonts,
      });
      for (const file of files) this.addWatchFile(file);
      for (const warning of warnings) this.warn(warning);
      return `import { registerClasses } from "swiftui-svelte/renderer";\nregisterClasses(${JSON.stringify(table)});\n`;
    },
    transform(code, id) {
      if (
        id.includes("\0") ||
        id.endsWith(".svelte") ||
        !/\bmountApp\s*\(/.test(code)
      )
        return null;
      return { code: `import "${ID}";\n${code}`, map: null };
    },
  };
}
