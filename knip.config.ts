import type { KnipConfig } from "knip";

const config: KnipConfig = {
  entry: [
    "src/index.ts",
    "src/renderer.ts",
    "src/vite.ts",
    "src/elements.ts",
    "example/src/main.ts",
  ],
  ignoreBinaries: ["swiftlint", "xcodegen"],
  ignoreFiles: ["changelogithub.config.ts"],
  ignoreIssues: {
    ".github/**/*.yml": ["binaries"],
    "tsconfig.json": ["unlisted"],
  },
};

export default config;
