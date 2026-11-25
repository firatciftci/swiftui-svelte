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
    await update(() => edit(byTestId("more"), "toggle", "expanded", true));
    await update(() => edit(byTestId("password"), "input", "value", "hunter2"));
    await update(() => edit(byTestId("notes"), "input", "value", "Line\nTwo"));
    await update(() => edit(byTestId("price"), "input", "value", 12.25));
    await update(() =>
      edit(byTestId("toppings"), "change", "value", ["cheese", "olives"]),
    );
    await update(() =>
      edit(byTestId("days"), "change", "value", ["2026-11-25", "2026-12-01"]),
    );
    await update(() => edit(byTestId("color"), "change", "value", "#00FF0080"));
    await update(() =>
      edit(byTestId("split"), "visibilitychange", "visibility", "detailOnly"),
    );
    await update(() =>
      edit(byTestId("split"), "compactcolumnchange", "compactcolumn", "detail"),
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
      isExpanded: true,
      password: "hunter2",
      notes: "Line\nTwo",
      price: 12.25,
      toppings: ["cheese", "olives"],
      days: ["2026-11-25", "2026-12-01"],
      color: "#00FF0080",
      visibility: "detailOnly",
      column: "detail",
    });
    await update(() => edit(byTestId("price"), "input", "value", null));
    expect(state().price).toBeNull();
  });

  it("send the bound value to the native control", () => {
    expect(byTestId("name")?.attributes.get("value")).toBe("");
    expect(byTestId("flavor")?.attributes.get("value")).toBe("vanilla");
    expect(byTestId("volume")?.attributes.get("value")).toBe(0.5);
    expect(byTestId("tabs")?.attributes.get("selection")).toBe("home");
    expect(byTestId("price")?.attributes.get("value")).toBe(4.5);
    expect(byTestId("toppings")?.attributes.get("value")).toEqual(["cheese"]);
    expect(byTestId("toppings")?.attributes.get("multiple")).toBe(true);
    expect(byTestId("days")?.attributes.get("value")).toEqual([]);
    expect(byTestId("color")?.attributes.get("value")).toBe("#FF0000");
    expect(byTestId("split")?.attributes.get("visibility")).toBe("all");
    expect(byTestId("split")?.attributes.get("compactcolumn")).toBe("sidebar");
    expect(byTestId("price")?.attributes.get("format")).toEqual({
      currency: "USD",
    });
    expect(byTestId("password")?.attributes.get("contenttype")).toBe(
      "password",
    );
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

  it("present and dismiss every presentation through bound flags", async () => {
    const names = [
      "sheet",
      "alert",
      "fullscreencover",
      "popover",
      "inspector",
      "confirmationdialog",
    ];
    for (const name of names) expect(find(name)).toBeUndefined();
    await update(() => dispatch(byTestId("open"), "click"));
    for (const name of names) expect(find(name)).toBeDefined();
    expect(find("alert")?.attributes.get("title")).toBe("Saved");
    expect(find("popover")?.attributes.get("detents")).toEqual([0.3, 200]);
    expect(find("inspector")?.attributes.get("columnwidth")).toEqual({
      ideal: 300,
    });
    for (const name of names)
      await update(() => dispatch(find(name), "dismiss"));
    for (const name of names) expect(find(name)).toBeUndefined();
    expect(state()).toMatchObject({
      isSheetPresented: false,
      isAlertPresented: false,
      isCoverPresented: false,
      isPopoverPresented: false,
      isInspectorPresented: false,
      isDialogPresented: false,
    });
  });
});
