import svelte from "eslint-plugin-svelte";
import { swiftuiSvelte } from "swiftui-svelte/eslint";
import ts from "typescript-eslint";
import svelteConfig from "./svelte.config.js";

export default ts.config(
  { ignores: ["ios/"] },
  ...ts.configs.recommended,
  ...svelte.configs.recommended,
  {
    files: ["**/*.svelte", "**/*.svelte.ts"],
    languageOptions: {
      parserOptions: {
        parser: ts.parser,
        extraFileExtensions: [".svelte"],
        svelteConfig,
      },
    },
  },
  ...swiftuiSvelte,
);
