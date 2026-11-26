import type { KnipConfig } from "knip";

const config: KnipConfig = {
  entry: [
    "example/src/main.ts",
    "test/native.ts",
    "test/web/native.ts",
    "test/size/main.ts",
  ],
  ignoreDependencies: ["typescript-eslint"],
  ignoreBinaries: ["swiftlint", "xcodegen"],
  ignoreFiles: [
    "template/**",
    "changelogithub.config.ts",
    "Tests/SvelteSwiftUITests/Fixtures/**",
    "example/src/app.css",
  ],
  ignoreIssues: {
    ".github/**/*.yml": ["binaries"],
    "tsconfig.json": ["unlisted"],
  },
};

export default config;
