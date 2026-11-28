import { flushSync } from "svelte";
import { afterEach, describe, expect, it, vi } from "vitest";
import { checkAttribute, checkElement, checkValue } from "swiftui-svelte/dev";
import { elements, modifiers } from "swiftui-svelte/known";
import { byTestId, dispatch, mountComponent, settle } from "./bridge.ts";
import FontSize from "./components/FontSize.svelte";
import Located from "./components/Located.svelte";
import Typo from "./components/Typo.svelte";

function fontSizeMessage(element: string): string {
  return `<${element}> has both font and size, so it ignores font="headline" and uses a fixed-size system font that doesn't follow Dynamic Type. Remove one of them, or set fontname to scale a custom font relative to that text style.`;
}

const warn = vi.spyOn(console, "warn").mockImplementation(() => {});

afterEach(() => warn.mockClear());

describe("development checks", () => {
  it("suggests the closest attribute for a misspelled one, once", async () => {
    const stop = mountComponent(Typo, { extra: { paddng: 8, weight: "bold" } });
    flushSync();
    await settle();
    const messages = warn.mock.calls.map(([message]: Array<unknown>) =>
      String(message),
    );
    expect(messages.toSorted((a, b) => a.localeCompare(b))).toEqual([
      `<txt> doesn't have an attribute named "paddng". Did you mean "padding"?`,
      "There's no element named <txtt>. Did you mean <txt>? If <txtt> is a native component, register it with SvelteView(components:).",
    ]);
    stop();
    checkAttribute("txt", "paddng");
    expect(warn).toHaveBeenCalledTimes(2);
  });

  it("leaves known attributes, native components, and distant names alone", () => {
    checkAttribute("txt", "weight");
    checkAttribute("btn", "onclick");
    checkAttribute("textfield", "debounce");
    checkAttribute("textfield", "axis");
    checkAttribute("mapview", "latitude");
    checkElement("mapview");
    checkElement("vstack");
    expect(warn).not.toHaveBeenCalled();
    checkAttribute("vstack", "zzzzzzzzzz");
    expect(warn).toHaveBeenCalledWith(
      `<vstack> doesn't have an attribute named "zzzzzzzzzz".`,
    );
  });

  it("warns once when size replaces font on an element without fontname", async () => {
    const updated = mountComponent(FontSize);
    flushSync();
    await settle();
    expect(warn).not.toHaveBeenCalled();
    for (let tap = 0; tap < 2; tap++) {
      dispatch(byTestId("updated"), "tap");
      flushSync();
      await settle();
    }
    expect(warn.mock.calls).toEqual([[fontSizeMessage("vstack")]]);
    updated();
    for (const initial of [20, 24]) {
      const created = mountComponent(FontSize, { initial });
      flushSync();
      await settle();
      created();
    }
    expect(warn.mock.calls).toEqual([
      [fontSizeMessage("vstack")],
      [fontSizeMessage("txt")],
    ]);
  });

  it("sends warnings to the native diagnostics channel when the host has one", () => {
    const native = vi.fn<(json: string) => void>();
    vi.stubGlobal("__nativeDiagnostic", native);
    try {
      checkAttribute("hstack", "qqqqqqqqqq");
      checkAttribute("hstack", "qqqqqqqqqq");
      checkElement("txtx");
    } finally {
      vi.unstubAllGlobals();
    }
    expect(warn).not.toHaveBeenCalled();
    expect(
      native.mock.calls.map(([json]): unknown => JSON.parse(json)),
    ).toEqual([
      {
        element: "hstack",
        attribute: "qqqqqqqqqq",
        message: `<hstack> doesn't have an attribute named "qqqqqqqqqq".`,
      },
      {
        element: "txtx",
        message:
          "There's no element named <txtx>. Did you mean <txt>? If <txtx> is a native component, register it with SvelteView(components:).",
      },
    ]);
  });

  it("names the source location of the element a warning is about", async () => {
    const native = vi.fn<(json: string) => void>();
    vi.stubGlobal("__nativeDiagnostic", native);
    try {
      const stop = mountComponent(Located, { extra: { colr: "red" } });
      flushSync();
      await settle();
      stop();
    } finally {
      vi.unstubAllGlobals();
    }
    expect(
      native.mock.calls
        .map(([json]): unknown => JSON.parse(json))
        .toSorted((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))),
    ).toEqual([
      {
        element: "tx",
        location: "src/Located.svelte:7:3",
        message:
          "There's no element named <tx>. Did you mean <txt>? If <tx> is a native component, register it with SvelteView(components:).",
      },
      {
        element: "txt",
        attribute: "colr",
        location: "src/Located.svelte:6:3",
        message: `<txt> doesn't have an attribute named "colr". Did you mean "color"?`,
      },
    ]);
  });

  it("warns once about a string that isn't one of an attribute's values", async () => {
    const stop = mountComponent(Typo, { extra: { font: "headlin" } });
    flushSync();
    await settle();
    stop();
    checkValue("txt", "font", "headlin");
    checkValue("vstack", "dir", "sideways");
    checkValue("txt", "font", "headline");
    checkValue("txt", "font", 17);
    checkValue("txt", "fixedsize", "");
    checkValue("txt", "color", "chartreuse-ish");
    checkValue("vstack", "blendmode", "zzzz");
    expect(
      warn.mock.calls
        .map(([message]: Array<unknown>) => String(message))
        .filter((message) => message.includes("isn't a value")),
    ).toEqual([
      `<txt> font="headlin" isn't a value font accepts, so it has no effect. Did you mean "headline"?`,
      `<vstack> dir="sideways" isn't a value dir accepts, so it has no effect. Use "ltr" or "rtl".`,
      `<vstack> blendmode="zzzz" isn't a value blendmode accepts, so it has no effect. docs/reference.md lists the values it takes.`,
    ]);
  });

  it("knows every element and modifier in elements.ts", () => {
    expect(modifiers.has("padding")).toBe(true);
    expect(elements.btn).toContain("onclick");
    expect(Object.keys(elements).length).toBeGreaterThan(70);
  });
});
