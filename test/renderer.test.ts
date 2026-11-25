import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mountApp } from "swiftui-svelte";
import {
  commits,
  dispatch,
  find,
  findAll,
  native,
  reset,
  serialize,
  settle,
} from "./bridge.ts";
import Counter from "./components/Counter.svelte";
import Items from "./components/Items.svelte";
import { resetState, state } from "./components/state.svelte.ts";
import Values from "./components/Values.svelte";

let unmount: (() => void) | undefined;

async function render(
  component: Parameters<typeof mountApp>[0],
): Promise<void> {
  unmount = mountApp(component);
  flushSync();
  await settle();
}

async function update(change: () => void): Promise<void> {
  change();
  flushSync();
  await settle();
}

beforeEach(() => {
  reset();
  resetState();
});

afterEach(() => {
  unmount?.();
  unmount = undefined;
});

describe("mounting", () => {
  it("sends a root fragment with the component's elements", async () => {
    await render(Counter);
    expect(serialize()).toMatchInlineSnapshot(`
      "#fragment
        <vstack spacing=8>
          <txt font="headline">
            #text "Count: 0"
          #text " "
          <btn>
            #text "Increment"
          #text " "
          <textfield value="">
          #text " "
          #comment ""
        #text """
    `);
  });

  it("commits the initial render in one batch", async () => {
    await render(Counter);
    expect(commits).toHaveLength(1);
  });

  it("removes everything from the root when unmounted", async () => {
    await render(Counter);
    unmount?.();
    unmount = undefined;
    await settle();
    expect(
      native.root?.children.filter((child) => child.kind === "element"),
    ).toEqual([]);
  });
});

describe("events", () => {
  it("runs handlers and sends the updated text", async () => {
    await render(Counter);
    await update(() => dispatch(find("btn"), "click"));
    await update(() => dispatch(find("btn"), "click"));
    expect(findAll("txt")[0]?.children[0]?.text).toBe("Count: 2");
  });

  it("passes the payload to the handler", async () => {
    await render(Counter);
    await update(() => dispatch(find("textfield"), "input", "Ada"));
    expect(find("textfield")?.attributes.get("value")).toBe("Ada");
    expect(findAll("txt")[1]?.children[0]?.text).toBe("Hello, Ada!");
  });

  it("never sends handlers as attributes", async () => {
    await render(Counter);
    expect([...(find("btn")?.attributes.keys() ?? [])]).toEqual([]);
    expect(find("textfield")?.attributes.has("oninput")).toBe(false);
  });

  it("ignores events for unknown nodes", () => {
    expect(() => globalThis.__svelteDispatch(-1, "click", null)).not.toThrow();
  });

  it("batches several changes into one commit", async () => {
    await render(Counter);
    const before = commits.length;
    await update(() => {
      dispatch(find("btn"), "click");
      dispatch(find("textfield"), "input", "x");
    });
    expect(commits.length - before).toBe(1);
  });
});

describe("blocks", () => {
  it("reorders keyed rows by moving the same nodes", async () => {
    await render(Items);
    const ids = findAll("txt").map((node) => node.id);
    await update(() => state.items.reverse());
    expect(findAll("txt").map((node) => node.children[0]?.text)).toEqual([
      "3",
      "2",
      "1",
    ]);
    expect(findAll("txt").map((node) => node.id)).toEqual(ids.toReversed());
  });

  it("adds and removes keyed rows", async () => {
    await render(Items);
    await update(() => {
      state.items.splice(1, 1);
      state.items.push(4, 5);
      state.items.unshift(0);
    });
    expect(findAll("txt").map((node) => node.children[0]?.text)).toEqual([
      "0",
      "1",
      "3",
      "4",
      "5",
    ]);
  });

  it("swaps if and else branches", async () => {
    await render(Items);
    expect(find("divider")).toBeDefined();
    await update(() => (state.show = false));
    expect(find("divider")).toBeUndefined();
    expect(find("spacer")).toBeDefined();
  });
});

describe("attributes", () => {
  it("removes an attribute that becomes undefined", async () => {
    await render(Items);
    expect(find("list")?.attributes.get("padding")).toBe(8);
    await update(() => (state.padding = undefined));
    expect(find("list")?.attributes.has("padding")).toBe(false);
  });

  it("passes values through JSON", async () => {
    await render(Values);
    const attributes = Object.fromEntries(find("vstack")?.attributes ?? []);
    expect(attributes).toEqual({
      "data-number": 1.5,
      "data-boolean": true,
      "data-string": "text",
      "data-array": [1, "two", false],
      "data-object": { a: [1], b: 2 },
      "data-date": "2026-01-02T03:04:05.006Z",
    });
  });
});
