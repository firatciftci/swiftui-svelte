import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mountApp, protocol } from "swiftui-svelte";
import {
  byTestId,
  commits,
  dispatch,
  edit,
  find,
  findAll,
  native,
  ops,
  reset,
  serialize,
  settle,
} from "./bridge.ts";
import Boundary from "./components/Boundary.svelte";
import Controlled from "./components/Controlled.svelte";
import Counter from "./components/Counter.svelte";
import Items from "./components/Items.svelte";
import { resetState, state } from "./components/state.svelte.ts";
import Texts from "./components/Texts.svelte";
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
          <btn>
            #text "Increment"
          <textfield value="">"
    `);
  });

  it("announces the bridge protocol with the root", async () => {
    await render(Counter);
    expect(ops[0]).toEqual({ op: "root", id: native.root?.id, protocol });
  });

  it("never sends comments or whitespace-only text", async () => {
    await render(Counter);
    expect(serialize()).not.toContain("#comment");
    expect(serialize()).not.toMatch(/#text " *"/);
  });

  it("sends each element and attribute name once", async () => {
    await render(Counter);
    unmount?.();
    reset();
    await render(Counter);
    expect(ops.filter((op) => op.op === "name")).toEqual([]);
    expect(ops.filter((op) => op.op === "insert")).not.toEqual([]);
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
    expect(native.root?.children).toEqual([]);
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

describe("boundaries", () => {
  it("renders the failed snippet natively and recovers on reset", async () => {
    await render(Boundary);
    await update(() => (state.label = "boom"));
    expect(byTestId("failed")?.children[0]?.text).toBe("bad label");
    await update(() => dispatch(byTestId("retry"), "click"));
    expect(byTestId("failed")).toBeUndefined();
    expect(findAll("txt").map((node) => node.children[0]?.text)).toEqual([
      "fine",
    ]);
  });

  it("renders the failed snippet when the first render throws", async () => {
    state.label = "boom";
    await render(Boundary);
    expect(byTestId("failed")?.children[0]?.text).toBe("bad label");
  });
});

describe("controlled inputs", () => {
  it("corrects a value that the handler changes", async () => {
    await render(Controlled);
    await update(() => edit(byTestId("limited"), "input", "value", "abcdefg"));
    expect(byTestId("limited")?.attributes.get("value")).toBe("abcde");
  });

  it("restores a value that the handler rejects", async () => {
    await render(Controlled);
    await update(() => edit(byTestId("limited"), "input", "value", "abcdefg"));
    await update(() => edit(byTestId("limited"), "input", "value", "abcdefgh"));
    expect(byTestId("limited")?.attributes.get("value")).toBe("abcde");
  });

  it("leaves a field without a value alone", async () => {
    await render(Controlled);
    await update(() => edit(byTestId("uncontrolled"), "input", "value", "x"));
    expect(byTestId("uncontrolled")?.attributes.get("value")).toBe("x");
  });

  it("turns a toggle back off when the handler ignores it", async () => {
    await render(Controlled);
    await update(() => edit(byTestId("locked"), "change", "checked", true));
    expect(byTestId("locked")?.attributes.has("checked")).toBe(false);
  });

  it("keeps a toggle on when the handler accepts it", async () => {
    await render(Controlled);
    await update(() => edit(byTestId("free"), "change", "checked", true));
    expect(byTestId("free")?.attributes.get("checked")).not.toBeUndefined();
  });

  it("sends nothing extra when the handler accepts the value", async () => {
    await render(Controlled);
    reset();
    await update(() => edit(byTestId("limited"), "input", "value", "abc"));
    expect(ops).toEqual([
      { op: "attr", id: byTestId("limited")?.id, name: "value", value: "abc" },
    ]);
  });
});

describe("coalescing", () => {
  it("drops a node that is added and removed in the same batch", async () => {
    await render(Items);
    reset();
    await update(() => {
      state.show = false;
      flushSync();
      state.show = true;
    });
    expect(commits).toHaveLength(1);
    expect(serialize()).not.toContain("spacer");
    expect(
      ops.flatMap((op) => (op.op === "insert" ? op.node.name : [])),
    ).toEqual(["divider"]);
  });

  it("sends an attribute changed twice once, with its last value", async () => {
    await render(Items);
    reset();
    await update(() => {
      state.padding = 1;
      flushSync();
      state.padding = 2;
    });
    expect(ops.filter((op) => op.op === "attr")).toEqual([
      { op: "attr", id: find("list")?.id, name: "padding", value: 2 },
    ]);
  });

  it("sends text changed twice once", async () => {
    await render(Counter);
    reset();
    await update(() => {
      dispatch(find("btn"), "click");
      flushSync();
      dispatch(find("btn"), "click");
    });
    expect(ops).toEqual([
      { op: "text", id: findAll("txt")[0]?.children[0]?.id, text: "Count: 2" },
    ]);
  });

  it("folds changes to a new node into its insert", async () => {
    await render(Items);
    reset();
    await update(() => {
      state.items.push(4);
      flushSync();
      state.padding = 3;
      state.items.push(5);
    });
    expect(ops.map((op) => op.op)).toEqual(["attr", "insert", "insert"]);
    expect(findAll("txt").map((node) => node.children[0]?.text)).toEqual([
      "1",
      "2",
      "3",
      "4",
      "5",
    ]);
  });

  it("skips a commit when changes cancel out", async () => {
    await render(Counter);
    reset();
    await update(() => {
      dispatch(find("textfield"), "input", "x");
      flushSync();
      dispatch(find("textfield"), "input", "");
    });
    expect(ops.filter((op) => op.op === "insert")).toEqual([]);
    expect(serialize()).not.toContain("Hello");
  });
});

describe("text", () => {
  it("sends a text node once it has content", async () => {
    await render(Texts);
    expect(find("txt")?.children).toEqual([]);
    await update(() => (state.label = "Hi"));
    expect(find("txt")?.children.map((child) => child.text)).toEqual(["Hi"]);
    await update(() => (state.label = ""));
    expect(find("txt")?.children.map((child) => child.text)).toEqual([""]);
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
      "data-big": 12,
      "data-map": { a: 1, b: ["x"] },
      "data-special": [null, null, null, null, 0],
      "data-nested": { at: "2026-01-02T03:04:05.006Z" },
    });
  });

  it("sends a changed attribute value", async () => {
    await render(Values);
    await update(() => (state.values.number = 2));
    expect(find("vstack")?.attributes.get("data-number")).toBe(2);
    await update(() => (state.values.big = 2n ** 70n));
    expect(find("vstack")?.attributes.get("data-big")).toBe(2 ** 70);
  });
});
