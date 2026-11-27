import type { KnipConfig } from "knip";

const config: KnipConfig = {
  entry: [
    "example/src/main.ts",
    "test/native.ts",
    "test/web/native.ts",
    "test/size/main.ts",
    "test/jsc/main.ts",
    "example/src/routes/**/*.{svelte,ts}",
    "test/router/src/**/*.{svelte,ts}",
  ],
  ignoreDependencies: ["typescript-eslint"],
  ignoreBinaries: ["swiftlint", "xcodegen"],
  ignoreUnresolved: [/^\$app\//, /\$types$/],
  ignoreFiles: [
    "template/**",
    "changelogithub.config.ts",
    "Tests/SvelteSwiftUITests/Fixtures/**",
    "example/src/app.css",
    "test/jsc/app.css",
  ],
  ignoreIssues: {
    ".github/**/*.yml": ["binaries"],
    "tsconfig.json": ["unlisted"],
  },
};

export default config;
