import type { Plugin } from "vite";

export function swiftui({
  entry = "src/main.ts",
  outFile,
}: {
  entry?: string;
  outFile: string;
}): Plugin {
  const slash = outFile.lastIndexOf("/");
  return {
    name: "swiftui-svelte",
    config: () => ({
      publicDir: false,
      build: {
        target: "es2023",
        outDir: slash === -1 ? "." : outFile.slice(0, slash),
        emptyOutDir: false,
        minify: false,
        lib: {
          entry,
          formats: ["iife"],
          name: "SvelteApp",
          fileName: () => outFile.slice(slash + 1),
        },
      },
    }),
  };
}
