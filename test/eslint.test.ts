import { ESLint } from "eslint";
import { describe, expect, it } from "vitest";
import { swiftuiSvelte } from "swiftui-svelte/eslint";

describe("the ESLint preset", () => {
  it("flags browser globals that a native app doesn't have", async () => {
    const eslint = new ESLint({
      overrideConfigFile: true,
      overrideConfig: [
        ...swiftuiSvelte,
        {
          languageOptions: {
            globals: { document: "readonly", fetch: "readonly" },
          },
        },
      ],
    });
    const [result] = await eslint.lintText(
      "document.title = 'Inbox';\nawait fetch('/inbox');\n",
      { filePath: "app.js" },
    );
    expect(
      result?.messages.map(({ line, message }) => ({ line, message })),
    ).toEqual([
      {
        line: 1,
        message:
          "Unexpected use of 'document'. There's no DOM in a swiftui-svelte app. Use bind:this for element refs.",
      },
    ]);
  });
});
