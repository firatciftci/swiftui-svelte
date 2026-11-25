import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  byTestId,
  dispatch,
  edit,
  find,
  mountComponent,
  reset,
  settle,
} from "./bridge.ts";
import Bindings from "./components/Bindings.svelte";

let unmount: (() => void) | undefined;

async function update(change: () => void): Promise<void> {
  change();
  flushSync();
  await settle();
}

function state(): Record<string, unknown> {
  const text = byTestId("state")?.children[0]?.text ?? "{}";
  return JSON.parse(text) as Record<string, unknown>;
}

beforeEach(async () => {
  reset();
  unmount = mountComponent(Bindings);
  flushSync();
  await settle();
});

afterEach(() => {
  unmount?.();
  unmount = undefined;
});

describe("bindable components", () => {
  it("bind values that the native controls change", async () => {
    await update(() => edit(byTestId("name"), "input", "value", "Ada"));
    await update(() => edit(byTestId("on"), "change", "checked", true));
    await update(() => edit(byTestId("flavor"), "change", "value", "mint"));
    await update(() => edit(byTestId("volume"), "input", "value", 0.8));
    await update(() => edit(byTestId("count"), "change", "value", 2));
    await update(() =>
      edit(byTestId("date"), "change", "value", new Date(86_400_000)),
    );
    await update(() =>
      edit(byTestId("tabs"), "change", "selection", "settings"),
    );
    expect(state()).toMatchObject({
      name: "Ada",
      isOn: true,
      flavor: "mint",
      volume: 0.8,
      count: 2,
      date: 86_400_000,
      tab: "settings",
      changes: 1,
    });
  });

  it("send the bound value to the native control", () => {
    expect(byTestId("name")?.attributes.get("value")).toBe("");
    expect(byTestId("flavor")?.attributes.get("value")).toBe("vanilla");
    expect(byTestId("volume")?.attributes.get("value")).toBe(0.5);
    expect(byTestId("tabs")?.attributes.get("selection")).toBe("home");
  });

  it("let a function binding change the value the control shows", async () => {
    await update(() => edit(byTestId("short"), "input", "value", "abcdef"));
    expect(state().short).toBe("abc");
    expect(byTestId("short")?.attributes.get("value")).toBe("abc");
  });

  it("pass other handlers through", async () => {
    await update(() => dispatch(byTestId("name"), "submit"));
    expect(state().submitted).toBe(1);
  });

  it("present and dismiss sheets and alerts through bound flags", async () => {
    expect(find("sheet")).toBeUndefined();
    expect(find("alert")).toBeUndefined();
    await update(() => dispatch(byTestId("open"), "click"));
    expect(find("sheet")).toBeDefined();
    expect(find("alert")?.attributes.get("title")).toBe("Saved");
    await update(() => dispatch(find("sheet"), "dismiss"));
    await update(() => dispatch(find("alert"), "dismiss"));
    expect(find("sheet")).toBeUndefined();
    expect(find("alert")).toBeUndefined();
    expect(state()).toMatchObject({
      isSheetPresented: false,
      isAlertPresented: false,
    });
  });
});
