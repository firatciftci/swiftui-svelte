import { flushSync } from "svelte";
import { afterEach, describe, expect, it, vi } from "vitest";
import { checkAttribute, checkElement } from "swiftui-svelte/dev";
import { elements, modifiers } from "swiftui-svelte/known";
import { mountComponent, settle } from "./bridge.ts";
import Typo from "./components/Typo.svelte";

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

  it("knows every element and modifier in elements.ts", () => {
    expect(modifiers.has("padding")).toBe(true);
    expect(elements.btn).toContain("onclick");
    expect(Object.keys(elements).length).toBeGreaterThan(70);
  });
});
