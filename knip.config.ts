import type { KnipConfig } from "knip";

const config: KnipConfig = {
  entry: [
    "src/index.ts",
    "src/renderer.ts",
    "src/vite.ts",
    "src/env.ts",
    "src/app.ts",
    "src/elements.ts",
    "example/src/main.ts",
    "test/native.ts",
    "test/web/native.ts",
  ],
  ignoreBinaries: ["swiftlint", "xcodegen"],
  ignoreFiles: [
    "changelogithub.config.ts",
    "Tests/SvelteSwiftUITests/Fixtures/**",
    "example/src/paraglide/**",
  ],
  ignoreIssues: {
    ".github/**/*.yml": ["binaries"],
    "tsconfig.json": ["unlisted"],
  },
};

export default config;
