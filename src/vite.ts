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
    config: (user) => ({
      publicDir: false,
      build: {
        target: "es2023",
        outDir: slash === -1 ? "." : outFile.slice(0, slash),
        emptyOutDir: false,
        minify: user.build?.minify ?? false,
        sourcemap: user.build?.sourcemap ?? true,
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
