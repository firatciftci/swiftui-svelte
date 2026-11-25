import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { ref } from "swiftui-svelte";
import {
  byTestId,
  invocations,
  mountComponent,
  reset,
  settle,
} from "./bridge.ts";
import Refs from "./components/Refs.svelte";
import { field, list } from "./components/refs.ts";
import { resetState, state } from "./components/state.svelte.ts";

let unmount: (() => void) | undefined;

function id(testId: string): number {
  const node = byTestId(testId);
  if (node == null) throw new Error(`no ${testId}`);
  return node.id;
}

beforeEach(async () => {
  reset();
  resetState();
  unmount = mountComponent(Refs);
  flushSync();
  await settle();
});

afterEach(() => {
  unmount?.();
  unmount = undefined;
});

describe("ref", () => {
  it("sends focus, blur, and scroll requests for the attached element", async () => {
    field.focus();
    field.blur();
    field.scrollIntoView({ anchor: "top", animated: false });
    list.scrollTo("bottom");
    await settle();
    expect(
      invocations.map(({ id, method, options }) => ({ id, method, options })),
    ).toEqual([
      { id: id("field"), method: "focus", options: {} },
      { id: id("field"), method: "blur", options: {} },
      {
        id: id("field"),
        method: "scrollIntoView",
        options: { anchor: "top", animated: false },
      },
      { id: id("list"), method: "scrollTo", options: { edge: "bottom" } },
    ]);
  });

  it("waits until the element exists natively", async () => {
    state.show = false;
    flushSync();
    await settle();
    reset();
    state.show = true;
    flushSync();
    field.focus();
    await settle();
    expect(invocations).toHaveLength(1);
    expect(invocations[0]).toMatchObject({ method: "focus", known: true });
    expect(invocations[0]?.afterCommit).toBeGreaterThan(0);
  });

  it("resolves measurements with the host's reply", async () => {
    const measured = list.measure();
    await settle();
    const request = invocations.at(-1);
    expect(request).toMatchObject({ id: id("list"), method: "measure" });
    const rect = { x: 0, y: 62, width: 402, height: 500 };
    globalThis.__svelteReply(Number(request?.options.request), rect);
    await expect(measured).resolves.toEqual(rect);
  });

  it("keeps concurrent measurements apart", async () => {
    const first = list.measure();
    const second = field.measure();
    await settle();
    const [one, two] = invocations.map(({ options }) =>
      Number(options.request),
    );
    globalThis.__svelteReply(Number(two), null);
    globalThis.__svelteReply(Number(one), { x: 1, y: 2, width: 3, height: 4 });
    await expect(first).resolves.toEqual({ x: 1, y: 2, width: 3, height: 4 });
    await expect(second).resolves.toBeNull();
  });

  it("detaches when the element goes away", async () => {
    state.show = false;
    flushSync();
    await settle();
    reset();
    field.focus();
    await settle();
    expect(invocations).toEqual([]);
    await expect(field.measure()).resolves.toBeNull();
  });

  it("resolves null when the element is removed before the request goes out", async () => {
    const measured = field.measure();
    state.show = false;
    flushSync();
    await settle();
    await expect(measured).resolves.toBeNull();
    expect(invocations.filter(({ method }) => method === "measure")).toEqual(
      [],
    );
  });

  it("ignores values that aren't renderer elements", async () => {
    const other = ref();
    const detach = other({ kind: "element", id: id("field") });
    other.focus();
    await settle();
    expect(invocations).toEqual([]);
    await expect(other.measure()).resolves.toBeNull();
    detach();
  });
});
