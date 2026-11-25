import type { Component } from "svelte";
import { flushSync } from "svelte";
import { afterEach, describe, expect, it, vi } from "vitest";
import Catalog from "../example/src/Catalog.svelte";
import { modifierGroups, sections } from "../example/src/catalog/sections.ts";
import { dispatch, find, mountComponent, reset, settle } from "./bridge.ts";

const examples = import.meta.glob<Component>(
  "../example/src/catalog/*/*.svelte",
  { eager: true, import: "default" },
);
const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
const error = vi.spyOn(console, "error").mockImplementation(() => {});

afterEach(() => {
  warn.mockClear();
  error.mockClear();
  reset();
});

async function render(component: Component | undefined): Promise<void> {
  if (component == null) throw new Error("The example is missing.");
  const stop = mountComponent(component);
  flushSync();
  await settle();
  expect(warn).not.toHaveBeenCalled();
  expect(error).not.toHaveBeenCalled();
  stop();
}

describe("catalog", () => {
  it.each(sections.flatMap((section) => section.elements))(
    "renders the %s example with known attributes only",
    async (name) => {
      const component =
        examples[`../example/src/catalog/elements/${name}.svelte`];
      if (component == null) throw new Error(`There's no ${name} example.`);
      const stop = mountComponent(component);
      flushSync();
      await settle();
      if (find(name) == null) {
        dispatch(find("btn"), "click");
        flushSync();
        await settle();
      }
      expect(find(name)).toBeDefined();
      expect(warn).not.toHaveBeenCalled();
      expect(error).not.toHaveBeenCalled();
      stop();
    },
  );

  it.each(modifierGroups.map((group) => group.name))(
    "renders the %s modifiers example with known attributes only",
    async (name) => {
      await render(examples[`../example/src/catalog/modifiers/${name}.svelte`]);
    },
  );

  it("renders the catalog screen", async () => {
    await render(Catalog);
  });
});
