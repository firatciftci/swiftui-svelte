import { defineConfig } from "bumpp";

export default defineConfig({
  commit: "chore: release v{version}",
  files: [
    "package.json",
    "src/protocol.ts",
    "Sources/SvelteSwiftUI/Version.swift",
  ],
});
