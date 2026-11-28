import process from "node:process";
import { resolveConfig } from "vite";

function hasSync(api: unknown): api is { sync: () => void } {
  return (
    typeof api === "object" &&
    api != null &&
    "sync" in api &&
    typeof api.sync === "function"
  );
}

export async function sync(root = process.cwd()): Promise<void> {
  const config = await resolveConfig({ root, logLevel: "silent" }, "build");
  const plugin = config.plugins.find(({ name }) => name === "swiftui-svelte");
  if (plugin == null || !hasSync(plugin.api)) {
    throw new Error(
      `swiftui-svelte sync: the Vite config in ${root} doesn't use the swiftui() plugin, so there are no route types to write. Run sync from the folder with your vite.config.ts.`,
    );
  }
  plugin.api.sync();
}
