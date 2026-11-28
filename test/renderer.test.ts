import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { move, protocol, withAnimation } from "swiftui-svelte";
import { registerClasses } from "swiftui-svelte/renderer";
import {
  animations,
  byTestId,
  commits,
  dispatch,
  edit,
  find,
  findAll,
  invocations,
  lastMount,
  mountComponent,
  native,
  ops,
  reset,
  serialize,
  settle,
} from "./bridge.ts";
import Accessible from "./components/Accessible.svelte";
import Boundary from "./components/Boundary.svelte";
import Classes from "./components/Classes.svelte";
import Controlled from "./components/Controlled.svelte";
import Counter from "./components/Counter.svelte";
import Declared from "./components/Declared.svelte";
import DeclaredClasses from "./components/DeclaredClasses.svelte";
import Gestures from "./components/Gestures.svelte";
import Greeting from "./components/Greeting.svelte";
import Items from "./components/Items.svelte";
import Lifecycle from "./components/Lifecycle.svelte";
import { log, signals } from "./components/lifecycle.ts";
import Lists from "./components/Lists.svelte";
import NativeMap from "./components/NativeMap.svelte";
import NestedAnimation from "./components/NestedAnimation.svelte";
import "./components/native-elements.ts";
import Refresh from "./components/Refresh.svelte";
import { pending, refreshSignals } from "./components/refresh.ts";
import Scrolling from "./components/Scrolling.svelte";
import Slots from "./components/Slots.svelte";
import { resetState, state } from "./components/state.svelte.ts";
import Texts from "./components/Texts.svelte";
import Values from "./components/Values.svelte";

let unmount: (() => void) | undefined;

async function render(
  component: Parameters<typeof mountComponent>[0],
  props: Record<string, unknown> = {},
): Promise<void> {
  unmount = mountComponent(component, props);
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
  it("declares attributes that are written in the markup but undefined", async () => {
    await render(Declared);
    const insert = ops.find(
      (op) => op.op === "insert" && op.node.name === "vstack",
    );
    expect(insert?.op === "insert" ? insert.node.attributes : []).toEqual(
      expect.arrayContaining([
        ["opacity", null],
        ["background", null],
        ["spacing", 4],
      ]),
    );
    await update(() => {});
    expect(serialize()).toContain("<vstack spacing=4>");
  });

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
    expect(ops[0]).toEqual({
      op: "root",
      id: native.root?.id,
      protocol,
      mount: lastMount(),
    });
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
    expect(native.root).toBeNull();
  });
});

function text(): string | undefined {
  return find("txt")?.children[0]?.text;
}

describe("props and actions", () => {
  it("mounts a component with props from Swift", async () => {
    unmount = mountComponent(Greeting, { name: "Ada", count: 3 });
    await update(() => {});
    expect(text()).toBe("Ada: 3");
  });

  it("re-renders when Swift updates the props", async () => {
    unmount = mountComponent(Greeting, { name: "Ada", count: 3 });
    await update(() => {});
    await update(() =>
      globalThis.__svelteProps(
        lastMount(),
        JSON.stringify({ name: "Grace", count: 4 }),
      ),
    );
    expect(text()).toBe("Grace: 4");
    await update(() =>
      globalThis.__svelteProps(lastMount(), JSON.stringify({ name: "Grace" })),
    );
    expect(text()).toBe("Grace: 0");
  });

  it("calls back into Swift through actions", async () => {
    unmount = mountComponent(Greeting, { name: "Ada", count: 3 }, ["onsave"]);
    await update(() => {});
    native.actions.length = 0;
    await update(() => dispatch(find("btn"), "click"));
    expect(native.actions).toEqual([
      {
        mountId: lastMount(),
        name: "onsave",
        payload: { name: "Ada", count: 3, at: "1970-01-01T00:00:00.000Z" },
      },
    ]);
  });

  it("keeps actions when Swift updates the props", async () => {
    unmount = mountComponent(Greeting, { name: "Ada" }, ["onsave"]);
    await update(() => {});
    await update(() =>
      globalThis.__svelteProps(
        lastMount(),
        JSON.stringify({ name: "Lin", onsave: 1 }),
      ),
    );
    native.actions.length = 0;
    await update(() => dispatch(find("btn"), "click"));
    expect(native.actions.map((action) => action.name)).toEqual(["onsave"]);
  });

  it("adds and removes actions when Swift updates them", async () => {
    unmount = mountComponent(Greeting, { name: "Ada" });
    await update(() => {});
    await update(() =>
      globalThis.__svelteProps(
        lastMount(),
        JSON.stringify({ name: "Ada" }),
        JSON.stringify(["onsave"]),
      ),
    );
    native.actions.length = 0;
    await update(() => dispatch(find("btn"), "click"));
    expect(native.actions.map((action) => action.name)).toEqual(["onsave"]);
    await update(() =>
      globalThis.__svelteProps(
        lastMount(),
        JSON.stringify({ name: "Ada" }),
        JSON.stringify([]),
      ),
    );
    native.actions.length = 0;
    await update(() => dispatch(find("btn"), "click"));
    expect(native.actions).toEqual([]);
  });

  it("runs several mounts in one context", async () => {
    const first = mountComponent(Greeting, { name: "One" });
    const firstId = lastMount();
    unmount = mountComponent(Greeting, { name: "Two" });
    await update(() => {});
    const firstRoot = native.roots.get(firstId);
    expect(firstRoot?.children[0]?.children[0]?.text).toBe("One: 0");
    expect(native.root?.children[0]?.children[0]?.text).toBe("Two: 0");
    await update(first);
    expect(native.roots.has(firstId)).toBe(false);
    expect(firstRoot?.children).toEqual([]);
    expect(text()).toBe("Two: 0");
  });

  it("explains a missing component", () => {
    expect(() =>
      globalThis.__svelteMount(
        999,
        "Missing",
        JSON.stringify({ props: {}, actions: [] }),
      ),
    ).toThrow('No component named "Missing". Pass it to mountApp().');
  });

  it("doesn't mount when the host doesn't support the bundle's protocol", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.stubGlobal("__nativeProtocols", [protocol + 1]);
    try {
      unmount = mountComponent(Greeting, { name: "Ada" });
      await update(() => {});
      expect(native.root?.children).toEqual([]);
      expect(warn).toHaveBeenCalledWith(
        expect.stringContaining(
          `This bundle uses bridge protocol ${protocol}, but the app's SvelteSwiftUI package supports protocol ${protocol + 1}.`,
        ),
      );
    } finally {
      vi.unstubAllGlobals();
      warn.mockRestore();
    }
  });

  it("mounts when the host lists the bundle's protocol", async () => {
    vi.stubGlobal("__nativeProtocols", [protocol]);
    try {
      await render(Greeting, { name: "Ada" });
      expect(text()).toContain("Ada");
    } finally {
      vi.unstubAllGlobals();
    }
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

describe("observed events", () => {
  it("tells the host which elements listen for scroll and resize", async () => {
    await render(Scrolling);
    expect(byTestId("scroller")?.attributes.get("listens")).toEqual(["scroll"]);
    expect(byTestId("box")?.attributes.has("listens")).toBe(false);
    await update(() => dispatch(byTestId("scroller"), "scroll", { y: 42 }));
    expect(findAll("txt")[0]?.children[0]?.text).toBe("Offset 42");
    await update(() => dispatch(byTestId("toggle-size"), "click"));
    expect(byTestId("box")?.attributes.get("listens")).toEqual(["resize"]);
    await update(() =>
      dispatch(byTestId("box"), "resize", { width: 320, height: 40 }),
    );
    expect(findAll("txt")[1]?.children[0]?.text).toBe("Width 320");
    await update(() => dispatch(byTestId("toggle-scroll"), "click"));
    expect(byTestId("scroller")?.attributes.has("listens")).toBe(false);
  });

  it("tells the host which menus have a primary action", async () => {
    await render(Scrolling);
    expect(byTestId("menu")?.attributes.get("listens")).toEqual([
      "primaryaction",
    ]);
    expect(byTestId("plain-menu")?.attributes.has("listens")).toBe(false);
    await update(() => dispatch(byTestId("menu"), "primaryaction"));
    expect(findAll("txt")[2]?.children[0]?.text).toBe("Primary 1");
  });
});

function run(testid: string, request: number): void {
  const node = byTestId(testid);
  if (node == null) throw new Error(`no ${testid}`);
  globalThis.__svelteDispatch(node.id, "task", null, request);
}

describe("lifecycle", () => {
  beforeEach(() => {
    log.length = 0;
    signals.length = 0;
  });

  it("tells the host which elements run tasks and notice appearing", async () => {
    await render(Lifecycle);
    expect(byTestId("page")?.attributes.get("listens")).toEqual([
      "appear",
      "disappear",
      "task",
    ]);
    expect(byTestId("page")?.attributes.get("taskid")).toBe(1);
    await update(() => {
      dispatch(byTestId("page"), "appear");
      dispatch(byTestId("page"), "disappear");
    });
    expect(log).toEqual(["appear", "disappear"]);
  });

  it("aborts a canceled task without reporting an error and settles it", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout"] });
    try {
      await render(Lifecycle);
      await update(() => run("page", 11));
      expect(log).toEqual(["load 1"]);
      expect(signals[0]?.aborted).toBe(false);
      expect(settled()).toEqual([]);
      await update(() => dispatch(byTestId("next"), "click"));
      expect(byTestId("page")?.attributes.get("taskid")).toBe(2);
      await update(() =>
        globalThis.__svelteDispatch(
          byTestId("page")?.id ?? 0,
          "taskcancel",
          11,
        ),
      );
      expect(signals[0]?.aborted).toBe(true);
      expect(log).toEqual(["load 1", "cancel 2"]);
      await update(() => run("page", 12));
      expect(settled()).toEqual([11]);
      expect(() => vi.runOnlyPendingTimers()).not.toThrow();
      expect(signals[1]?.aborted).toBe(false);
    } finally {
      vi.useRealTimers();
    }
  });

  it("settles a synchronous task right away and ignores unknown cancels", async () => {
    await render(Lifecycle);
    await update(() => {
      run("quick", 13);
      globalThis.__svelteDispatch(0, "taskcancel", 99);
    });
    expect(log).toEqual(["quick"]);
    expect(settled()).toEqual([13]);
  });
});

function labels(): Array<string | undefined> {
  return findAll("txt").map((node) => node.children[0]?.text);
}

describe("gestures", () => {
  it("tells the host which gestures an element handles and passes their payloads", async () => {
    await render(Gestures);
    const canvas = byTestId("canvas");
    expect(canvas?.attributes.get("listens")).toEqual([
      "drag",
      "longpress",
      "magnify",
      "tap",
    ]);
    expect(canvas?.attributes.get("tapcount")).toBe(2);
    await update(() => {
      dispatch(canvas, "tap", { x: 4, y: 8 });
      dispatch(canvas, "tap", { x: 4, y: 8 });
      dispatch(canvas, "drag", {
        phase: "changed",
        location: { x: 30, y: 0 },
        start: { x: 0, y: 0 },
        translation: { x: 30, y: 0 },
        velocity: { x: 120, y: 0 },
        predictedEnd: { x: 60, y: 0 },
      });
      dispatch(canvas, "magnify", {
        phase: "ended",
        magnification: 1.5,
        velocity: 0,
      });
    });
    expect(labels()).toEqual(["Taps 2", "Drag 30", "Scale 1.5"]);
    await update(() => dispatch(canvas, "longpress"));
    expect(labels()[0]).toBe("Taps 0");
  });
});

describe("native elements", () => {
  it("passes attributes to an app's own element and receives its events", async () => {
    await render(NativeMap);
    const map = byTestId("map");
    expect(map?.name).toBe("weathermap");
    expect(map?.attributes.get("latitude")).toBe(41.88);
    await update(() =>
      dispatch(map, "regionchange", { latitude: 40.71, longitude: -74 }),
    );
    expect(find("txt")?.children[0]?.text).toBe("40.71");
  });
});

describe("accessibility", () => {
  it("passes accessibility attributes and listens for adjustments", async () => {
    await render(Accessible);
    const rating = byTestId("rating");
    expect(rating?.attributes.get("a11ychildren")).toBe("combine");
    expect(rating?.attributes.get("a11ylabel")).toBe("Rating");
    expect(rating?.attributes.get("a11yvalue")).toBe(3);
    expect(rating?.attributes.get("a11ytraits")).toEqual([
      "button",
      "selected",
    ]);
    expect(rating?.attributes.get("a11yactions")).toEqual(["Reset", "Maximum"]);
    expect(rating?.attributes.get("listens")).toEqual(["a11yadjust"]);
    expect(byTestId("title")?.attributes.get("a11yheading")).toBe(1);
    expect(byTestId("decoration")?.attributes.get("a11yhidden")).toBe("");

    await update(() => dispatch(rating, "a11yadjust", "increment"));
    expect(byTestId("rating")?.attributes.get("a11yvalue")).toBe(4);
    await update(() => dispatch(rating, "a11yadjust", "decrement"));
    await update(() => dispatch(rating, "a11yadjust", "decrement"));
    expect(byTestId("rating")?.attributes.get("a11yvalue")).toBe(2);
    await update(() => dispatch(rating, "a11yaction", "Maximum"));
    expect(byTestId("rating")?.attributes.get("a11yvalue")).toBe(5);
    expect(byTestId("last")?.children[0]?.text).toBe("Maximum");
  });
});

function refresh(testid: string, request: number): void {
  const node = byTestId(testid);
  if (node == null) throw new Error(`no ${testid}`);
  globalThis.__svelteDispatch(node.id, "refresh", null, request);
}

function settled(): Array<number> {
  return invocations
    .filter((invocation) => invocation.method === "settled")
    .map((invocation) => Number(invocation.options.request));
}

describe("refresh", () => {
  beforeEach(() => {
    pending.length = 0;
    refreshSignals.length = 0;
  });

  it("aborts a refresh's signal when the host cancels it, without reporting the rejection", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout"] });
    try {
      await render(Refresh);
      await update(() => refresh("abortable", 11));
      expect(refreshSignals.map((signal) => signal.aborted)).toEqual([false]);
      expect(settled()).toEqual([]);
      await update(() =>
        globalThis.__svelteDispatch(
          byTestId("abortable")?.id ?? NaN,
          "taskcancel",
          11,
        ),
      );
      expect(refreshSignals[0]?.aborted).toBe(true);
      expect(settled()).toEqual([11]);
      expect(() => vi.runOnlyPendingTimers()).not.toThrow();
    } finally {
      vi.useRealTimers();
    }
  });

  it("tells the host which elements refresh", async () => {
    await render(Refresh);
    expect(byTestId("feed")?.attributes.get("listens")).toEqual(["refresh"]);
    expect(byTestId("plain")?.attributes.has("listens")).toBe(false);
  });

  it("settles a refresh after the handler's promise resolves and its changes commit", async () => {
    await render(Refresh);
    await update(() => refresh("feed", 7));
    expect(settled()).toEqual([]);
    const before = commits.length;
    await update(() => pending[0]?.());
    expect(settled()).toEqual([7]);
    const invocation = invocations.find((item) => item.method === "settled");
    expect(invocation?.id).toBe(byTestId("feed")?.id);
    expect(invocation?.afterCommit).toBeGreaterThan(before);
    expect(find("txt", byTestId("feed"))?.children[0]?.text).toBe(
      "Refreshes 1",
    );
  });

  it("settles a synchronous handler right away", async () => {
    await render(Refresh);
    await update(() => refresh("quick", 3));
    expect(settled()).toEqual([3]);
  });

  it("settles an element without a handler and an unknown element", async () => {
    await render(Refresh);
    await update(() => {
      refresh("plain", 4);
      globalThis.__svelteDispatch(-1, "refresh", null, 5);
    });
    expect(settled()).toEqual([4, 5]);
  });

  it("settles a failed refresh and reports the error", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout"] });
    try {
      await render(Refresh);
      await update(() => refresh("failing", 6));
      expect(settled()).toEqual([6]);
      expect(() => vi.runOnlyPendingTimers()).toThrow("offline");
    } finally {
      vi.useRealTimers();
    }
  });

  it("settles a refresh whose handler throws and reports the error", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout"] });
    try {
      await render(Refresh);
      await update(() => {
        expect(() => refresh("throwing", 9)).not.toThrow();
      });
      expect(settled()).toEqual([9]);
      expect(() => vi.runOnlyPendingTimers()).toThrow("unreachable");
    } finally {
      vi.useRealTimers();
    }
  });

  it("ignores a refresh for an element that was already removed", async () => {
    await render(Refresh);
    const id = byTestId("feed")?.id ?? NaN;
    await update(() => dispatch(byTestId("hide"), "click"));
    await update(() => globalThis.__svelteDispatch(id, "refresh", null, 10));
    expect(pending).toEqual([]);
    expect(settled()).toEqual([10]);
  });

  it("ignores events for elements of an unmounted app", async () => {
    await render(Refresh);
    const id = byTestId("feed")?.id ?? NaN;
    unmount?.();
    unmount = undefined;
    await update(() => globalThis.__svelteDispatch(id, "refresh", null, 11));
    expect(pending).toEqual([]);
    expect(settled()).toEqual([11]);
  });

  it("settles a refresh whose element was removed", async () => {
    await render(Refresh);
    await update(() => refresh("feed", 8));
    await update(() => dispatch(byTestId("hide"), "click"));
    expect(byTestId("feed")).toBeUndefined();
    await update(() => pending[0]?.());
    expect(settled()).toEqual([8]);
  });
});

function texts(): Array<string | undefined> {
  return findAll("txt", byTestId("section")).map(
    (node) => node.children[0]?.text,
  );
}

function moved(from: Array<number>, to: number): Array<string> {
  const items = ["a", "b", "c", "d", "e"];
  move(items, from, to);
  return items;
}

describe("lists", () => {
  it("tells the host which lists select and which sections edit rows", async () => {
    await render(Lists);
    expect(byTestId("rows")?.attributes.get("listens")).toEqual([
      "selectionchange",
    ]);
    expect(byTestId("section")?.attributes.get("listens")).toEqual([
      "delete",
      "move",
    ]);
    expect(byTestId("plain")?.attributes.has("listens")).toBe(false);
  });

  it("binds the selection and edit mode", async () => {
    await render(Lists);
    await update(() =>
      edit(byTestId("rows"), "selectionchange", "selection", "B"),
    );
    await update(() =>
      edit(byTestId("rows"), "editingchange", "editing", true),
    );
    expect(byTestId("picked")?.children[0]?.text).toBe("B editing 0");
    expect(byTestId("rows")?.attributes.get("selection")).toBe("B");
    expect(byTestId("rows")?.attributes.get("editing")).toBe(true);
  });

  it("keeps the selection and edit mode when the handlers reject changes", async () => {
    await render(Lists);
    await update(() =>
      edit(byTestId("locked"), "selectionchange", "selection", "B"),
    );
    await update(() =>
      edit(byTestId("locked"), "editingchange", "editing", true),
    );
    expect(byTestId("locked")?.attributes.get("selection")).toBe("A");
    expect(byTestId("locked")?.attributes.get("editing")).toBe(false);
  });

  it("deletes and moves rows by index", async () => {
    await render(Lists);
    await update(() => dispatch(byTestId("section"), "delete", [0, 2]));
    expect(texts()).toEqual(["B", "D"]);
    await update(() =>
      dispatch(byTestId("section"), "move", { from: [0], to: 2 }),
    );
    expect(texts()).toEqual(["D", "B"]);
    expect(byTestId("picked")?.children[0]?.text).toBe("none done 1");
  });

  it("sends row tags and options as attributes", async () => {
    await render(Lists);
    const row = findAll("txt", byTestId("section"))[1];
    expect(row?.attributes.get("tag")).toBe("B");
    expect(row?.attributes.get("rowseparator")).toBe("hidden");
    expect(byTestId("section")?.attributes.get("indexlabel")).toBe("R");
  });
});

describe("move", () => {
  it("moves rows the way SwiftUI's onMove reports them", () => {
    expect(moved([0], 2)).toEqual(["b", "a", "c", "d", "e"]);
    expect(moved([4], 0)).toEqual(["e", "a", "b", "c", "d"]);
    expect(moved([1, 3], 5)).toEqual(["a", "c", "e", "b", "d"]);
    expect(moved([3, 1], 0)).toEqual(["b", "d", "a", "c", "e"]);
    expect(moved([2], 2)).toEqual(["a", "b", "c", "d", "e"]);
    expect(moved([2], 3)).toEqual(["a", "b", "c", "d", "e"]);
  });

  it("ignores indices outside the array", () => {
    expect(moved([7, -1], 0)).toEqual(["a", "b", "c", "d", "e"]);
    expect(moved([0, 0], 9)).toEqual(["b", "c", "d", "e", "a"]);
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

describe("slots", () => {
  it("renders snippets into header, footer, label, overlay, and background elements", async () => {
    await render(Slots);
    expect(serialize()).toMatchInlineSnapshot(`
      "#fragment
        <sectionview>
          <header>
            <hstack>
              <sfsymbol name="leaf">
              <txt>
                #text "Fruit"
          <txt>
            #text "Apple"
          <footer>
            <txt>
              #text "Seasonal"
        <picker value="a">
          <label>
            <hstack>
              <sfsymbol name="leaf">
              <txt>
                #text "Pick one"
          <choice value="a">
            #text "A"
        <txt>
          #text "Badge "
          <overlay alignment="topTrailing">
            <sfsymbol name="circle.fill">
          #text " "
          <background>
            <zstack>"
    `);
  });
});

describe("withAnimation", () => {
  it("sends the callback's changes in their own animated commit", async () => {
    await render(Items);
    reset();
    state.padding = 4;
    withAnimation(
      () => {
        state.show = false;
      },
      { type: "bouncy", duration: 300 },
    );
    expect(animations).toEqual([
      undefined,
      JSON.stringify({ type: "bouncy", duration: 300 }),
    ]);
    expect(JSON.parse(commits[0] ?? "[]")).toContain(4);
    expect(find("list")?.attributes.get("padding")).toBe(4);
    expect(find("divider")).toBeUndefined();
    expect(find("spacer")).toBeDefined();
  });

  it("returns the callback's result and defaults to SwiftUI's animation", async () => {
    await render(Items);
    reset();
    const result = withAnimation(() => {
      state.items.push(4);
      return "pushed";
    });
    expect(result).toBe("pushed");
    expect(animations).toEqual(["true"]);
    expect(findAll("txt")).toHaveLength(4);
  });

  it("sends nothing when the callback changes nothing", async () => {
    await render(Items);
    reset();
    withAnimation(() => {}, "snappy");
    expect(commits).toEqual([]);
  });

  it("passes false through so the host can turn animations off", async () => {
    await render(Items);
    reset();
    withAnimation(() => (state.show = false), false);
    expect(animations).toEqual(["false"]);
  });

  it("applies a withAnimation from an effect of the change after the change, with its own animation", async () => {
    await render(NestedAnimation);
    reset();
    const result = withAnimation(() => (state.show = false), "smooth");
    expect(result).toBe(false);
    expect(animations).toEqual(['"smooth"', '"snappy"']);
    expect(find("txt")).toBeUndefined();
    expect(find("circle")?.attributes.get("opacity")).toBe(0);
  });

  it("leaves later commits unanimated", async () => {
    await render(Items);
    reset();
    withAnimation(() => (state.show = false), "smooth");
    await update(() => (state.show = true));
    expect(animations).toEqual(['"smooth"', undefined]);
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

  it("restores a value when the handler throws and reports the error", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout"] });
    try {
      await render(Controlled);
      await update(() => {
        expect(() =>
          edit(byTestId("throwing"), "input", "value", "typed"),
        ).not.toThrow();
      });
      expect(byTestId("throwing")?.attributes.get("value")).toBe("");
      expect(() => vi.runOnlyPendingTimers()).toThrow("rejected input");
    } finally {
      vi.useRealTimers();
    }
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

  it("returns to the selected tab when the handler rejects a switch", async () => {
    await render(Controlled);
    await update(() =>
      edit(byTestId("pinned"), "change", "selection", "second"),
    );
    expect(byTestId("pinned")?.attributes.get("selection")).toBe("first");
  });

  it("keeps the split view's columns when the handler rejects a change", async () => {
    await render(Controlled);
    await update(() =>
      edit(byTestId("split"), "visibilitychange", "visibility", "detailOnly"),
    );
    await update(() =>
      edit(byTestId("split"), "compactcolumnchange", "compactcolumn", "detail"),
    );
    expect(byTestId("split")?.attributes.get("visibility")).toBe("all");
    expect(byTestId("split")?.attributes.get("compactcolumn")).toBe("sidebar");
  });

  it("keeps the search field's state when the handlers reject changes", async () => {
    await render(Controlled);
    const search = find("searchable");
    await update(() => edit(search, "input", "value", "other"));
    await update(() => edit(search, "presentedchange", "presented", true));
    await update(() => edit(search, "tokenschange", "tokens", []));
    await update(() => edit(search, "scopechange", "selectedscope", "recent"));
    expect(search?.attributes.get("value")).toBe("fixed");
    expect(search?.attributes.get("presented")).toBe(false);
    expect(search?.attributes.get("tokens")).toEqual(["Fruit"]);
    expect(search?.attributes.get("selectedscope")).toBe("all");
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

  it("serializes batches without a replacer when a value holds a Map", async () => {
    const stringify = vi.spyOn(JSON, "stringify");
    try {
      await render(Values);
      await update(() => (state.values.big = 2n ** 70n));
      const batches = stringify.mock.calls.filter(
        ([value, replacer]) => Array.isArray(value) && replacer != null,
      );
      expect(batches).toEqual([]);
    } finally {
      stringify.mockRestore();
    }
    expect(find("vstack")?.attributes.get("data-map")).toEqual({
      a: 1,
      b: ["x"],
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

function declaredByStack(): Array<string> {
  const declared: Array<string> = [];
  for (const op of ops) {
    if (op.op !== "insert" || op.node.name !== "vstack") continue;
    for (const [attribute, value] of op.node.attributes)
      if (value === null) declared.push(attribute);
  }
  return declared;
}

describe("tailwind classes", () => {
  const padding = { top: 16, leading: 16, bottom: 16, trailing: 16 };
  const table = {
    tokens: {
      "p-4": [{ order: 1, attrs: { padding } }],
      "bg-white": [{ order: 2, attrs: { background: "#ffffff" } }],
      "dark:bg-black": [
        { order: 3, when: ["dark"], attrs: { background: "#000000" } },
      ],
      "md:p-2": [
        {
          order: 4,
          when: [">=768"],
          attrs: { padding: { top: 8, leading: 8, bottom: 8, trailing: 8 } },
        },
      ],
    },
    statics: {},
    breakpoints: [768],
  };

  beforeEach(() => registerClasses(table));
  afterEach(() => {
    registerClasses({ tokens: {}, statics: {}, breakpoints: [] });
    __svelteEnvironment(
      JSON.stringify({ colorScheme: "light", viewportWidth: 0 }),
    );
  });

  it("applies the attributes of each class, sent without the class name", async () => {
    await render(Classes, { className: "p-4 bg-white" });
    const stack = find("vstack");
    expect(stack?.attributes.get("padding")).toEqual(padding);
    expect(stack?.attributes.get("background")).toBe("#ffffff");
    expect(stack?.attributes.has("class")).toBe(false);
  });

  it("lets an explicit attribute replace the one a class sets", async () => {
    await render(Classes, { className: "p-4 bg-white", padding: 0 });
    const stack = find("vstack");
    expect(stack?.attributes.get("padding")).toBe(0);
    expect(stack?.attributes.get("background")).toBe("#ffffff");
  });

  it("applies conditional classes for the current color scheme and width", async () => {
    __svelteEnvironment(
      JSON.stringify({ colorScheme: "dark", viewportWidth: 800 }),
    );
    await render(Classes, { className: "bg-white dark:bg-black md:p-2" });
    const stack = find("vstack");
    expect(stack?.attributes.get("background")).toBe("#000000");
    expect(stack?.attributes.get("padding")).toEqual({
      top: 8,
      leading: 8,
      bottom: 8,
      trailing: 8,
    });
  });

  it("declares the attributes of classes that don't apply yet", async () => {
    await render(Classes, { className: "dark:bg-black" });
    expect(declaredByStack()).toContain("background");
    await render(DeclaredClasses, { on: false });
    expect(declaredByStack()).toEqual(
      expect.arrayContaining(["background", "padding"]),
    );
  });

  it("re-resolves conditional classes when the environment changes", async () => {
    await render(Classes, { className: "bg-white dark:bg-black" });
    expect(find("vstack")?.attributes.get("background")).toBe("#ffffff");
    __svelteEnvironment(JSON.stringify({ colorScheme: "dark" }));
    await settle();
    expect(find("vstack")?.attributes.get("background")).toBe("#000000");
  });
});

const insets = (top: number) => ({ top, leading: 0, bottom: 0, trailing: 0 });

describe("tailwind native conditions", () => {
  const table = {
    tokens: {
      "ios:p-1": [
        {
          order: 1,
          when: ["platform:ios"],
          attrs: { padding: { top: 4, leading: 4, bottom: 4, trailing: 4 } },
        },
      ],
      "android:p-2": [
        {
          order: 2,
          when: ["platform:android"],
          attrs: { padding: { top: 8, leading: 8, bottom: 8, trailing: 8 } },
        },
      ],
      "web:p-3": [{ order: 3, when: ["web"], attrs: { padding: 12 } }],
      "landscape:h-1": [
        {
          order: 4,
          when: ["orientation:landscape"],
          attrs: { border: { width: 1 } },
        },
      ],
      "pt-safe": [
        {
          order: 5,
          dynamic: true,
          attrs: {
            padding: {
              top: { op: "+", args: [{ op: "insetTop", args: [] }, 8] },
            },
          },
        },
      ],
      hairline: [
        {
          order: 6,
          dynamic: true,
          attrs: {
            $borderWidth: {
              top: { op: "hairlineWidth", args: [] },
              leading: { op: "hairlineWidth", args: [] },
              bottom: { op: "hairlineWidth", args: [] },
              trailing: { op: "hairlineWidth", args: [] },
            },
          },
        },
      ],
    },
    statics: {},
    breakpoints: [],
  };

  beforeEach(() => registerClasses(table));
  afterEach(() => {
    registerClasses({ tokens: {}, statics: {}, breakpoints: [] });
    __svelteEnvironment(
      JSON.stringify({
        platform: "unknown",
        viewportWidth: 0,
        viewportHeight: 0,
        pixelRatio: 1,
        safeAreaInsets: insets(0),
      }),
    );
  });

  it("applies a platform's rules only on that platform, and never on the web", async () => {
    __svelteEnvironment(JSON.stringify({ platform: "ios" }));
    await render(Classes, { className: "ios:p-1 android:p-2 web:p-3" });
    expect(find("vstack")?.attributes.get("padding")).toEqual({
      top: 4,
      leading: 4,
      bottom: 4,
      trailing: 4,
    });
  });

  it("flips the Android rules when the host reports Android", async () => {
    __svelteEnvironment(JSON.stringify({ platform: "android" }));
    await render(Classes, { className: "ios:p-1 android:p-2 web:p-3" });
    expect(find("vstack")?.attributes.get("padding")).toEqual({
      top: 8,
      leading: 8,
      bottom: 8,
      trailing: 8,
    });
  });

  it("applies orientation from the viewport size the host reports", async () => {
    __svelteEnvironment(
      JSON.stringify({ viewportWidth: 800, viewportHeight: 400 }),
    );
    await render(Classes, { className: "landscape:h-1" });
    expect(find("vstack")?.attributes.get("border")).toEqual({ width: 1 });
  });

  it("measures safe-area offsets and re-resolves them when the insets change", async () => {
    __svelteEnvironment(JSON.stringify({ safeAreaInsets: insets(47) }));
    await render(Classes, { className: "pt-safe" });
    expect(find("vstack")?.attributes.get("padding")).toEqual({ top: 55 });
    __svelteEnvironment(JSON.stringify({ safeAreaInsets: insets(59) }));
    await settle();
    expect(find("vstack")?.attributes.get("padding")).toEqual({ top: 67 });
  });

  it("measures hairlines from the host's pixel ratio", async () => {
    __svelteEnvironment(JSON.stringify({ pixelRatio: 3 }));
    await render(Classes, { className: "hairline" });
    expect(find("vstack")?.attributes.get("border")).toEqual({
      width: { top: 1 / 3, leading: 1 / 3, bottom: 1 / 3, trailing: 1 / 3 },
    });
  });
});
