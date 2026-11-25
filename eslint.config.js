import antfu from "@antfu/eslint-config";

export default antfu({
  type: "lib",
  ignores: ["**/*.md", "dist/**", "build/**", ".build/**", "example/ios/**"],
  stylistic: false,
  markdown: false,
  antislop: true,
  svelte: true,
  typescript: {
    tsconfigPath: "tsconfig.json",
    erasableOnly: true,
    overrides: {
      "ts/array-type": ["error", { default: "generic" }],
      "ts/consistent-indexed-object-style": ["error", "record"],
      "ts/consistent-type-definitions": "off",
      "ts/consistent-type-imports": [
        "warn",
        { prefer: "type-imports", fixStyle: "separate-type-imports" },
      ],
      "ts/method-signature-style": "off",
      "ts/no-dynamic-delete": "error",
      "ts/no-explicit-any": "error",
      "ts/no-inferrable-types": "error",
    },
    overridesTypeAware: {
      "ts/non-nullable-type-assertion-style": "error",
      "ts/no-array-delete": "error",
      "ts/no-deprecated": "error",
      "ts/no-duplicate-type-constituents": "error",
      "ts/no-redundant-type-constituents": "error",
      "ts/no-unnecessary-boolean-literal-compare": "error",
      "ts/no-unnecessary-condition": "error",
      "ts/prefer-includes": "warn",
      "ts/prefer-nullish-coalescing": "error",
      "ts/prefer-optional-chain": "warn",
      "ts/prefer-regexp-exec": "error",
      "ts/prefer-string-starts-ends-with": "error",
      "ts/switch-exhaustiveness-check": [
        "warn",
        { considerDefaultExhaustiveForUnions: true },
      ],
      "ts/use-unknown-in-catch-callback-variable": "error",
    },
  },
  unicorn: {
    allRecommended: true,
    overrides: {
      "unicorn/better-regex": "error",
      "unicorn/filename-case": [
        "error",
        {
          cases: { kebabCase: true, pascalCase: true },
          ignore: ["README.md", "LICENSE"],
        },
      ],
      "unicorn/max-nested-calls": "off",
      "unicorn/name-replacements": "off",
      "unicorn/no-break-in-nested-loop": "off",
      "unicorn/no-nested-ternary": "off",
      "unicorn/no-non-function-verb-prefix": "off",
      "unicorn/no-null": "off",
      "unicorn/no-negated-condition": "off",
      "unicorn/no-top-level-side-effects": "off",
      "unicorn/no-thenable": "off",
      "unicorn/prevent-abbreviations": "off",
      "unicorn/prefer-ternary": "off",
      "unicorn/single-line-block-comment-style": "off",
    },
  },
  imports: {
    overrides: {
      "perfectionist/sort-imports": [
        "error",
        {
          tsconfig: {
            rootDir: new URL(".", import.meta.url).pathname.slice(0, -1),
            filename: "tsconfig.json",
          },
          newlinesBetween: 0,
          order: "asc",
          type: "natural",
        },
      ],
    },
  },
  rules: {
    "antfu/no-top-level-await": ["off"],
    "jsonc/sort-keys": "off",
    "node/no-process-env": "error",
    "no-console": ["error", { allow: ["warn"] }],
    "no-restricted-imports": ["error", { patterns: ["..*"] }],
    "pnpm/yaml-enforce-settings": "off",
  },
}).append(
  {
    files: ["example/**", "*.config.ts", "*.config.js"],
    rules: { "ts/explicit-function-return-type": "off" },
  },
  { files: ["example/src/Bench.svelte"], rules: { "no-console": "off" } },
  {
    files: ["src/host.ts", "src/renderer.ts"],
    rules: { "unicorn/no-global-object-property-assignment": "off" },
  },
  {
    files: ["src/host.ts"],
    rules: { "no-console": "off", "ts/no-unnecessary-condition": "off" },
  },
  {
    files: ["src/elements.ts"],
    rules: { "unicorn/consistent-boolean-name": "off", "vars-on-top": "off" },
  },
  {
    files: ["test/**"],
    rules: {
      "unicorn/better-dom-traversing": "off",
      "unicorn/no-array-reverse": "off",
      "unicorn/no-top-level-assignment-in-function": "off",
    },
  },
);
