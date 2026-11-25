import { flushSync } from "svelte";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  matchURL,
  onActive,
  onBackground,
  onInactive,
  onMemoryWarning,
  onOpenURL,
  restorable,
} from "swiftui-svelte/app";
import { createStorage } from "swiftui-svelte/web/storage";
import "./bridge.ts";

const cleanups: Array<() => void> = [];

function phase(scenePhase: "active" | "inactive" | "background"): void {
  globalThis.__svelteEnvironment(JSON.stringify({ scenePhase }));
}

afterEach(() => {
  for (const cleanup of cleanups.splice(0)) cleanup();
  phase("active");
});

describe("swiftui-svelte/app", () => {
  it("reports scene phase changes in order", () => {
    const seen: Array<string> = [];
    cleanups.push(
      onActive(() => {
        seen.push("active");
      }),
      onInactive(() => {
        seen.push("inactive");
      }),
      onBackground(() => {
        seen.push("background");
      }),
    );
    phase("inactive");
    phase("background");
    phase("background");
    phase("inactive");
    phase("active");
    expect(seen).toEqual(["inactive", "background", "inactive", "active"]);
  });

  it("ignores environment changes that leave the phase alone", () => {
    const listener = vi.fn();
    cleanups.push(onActive(listener), onBackground(listener));
    globalThis.__svelteEnvironment(JSON.stringify({ keyboardHeight: 300 }));
    expect(listener).not.toHaveBeenCalled();
  });

  it("stops calling a listener after it unsubscribes", () => {
    const listener = vi.fn();
    const unsubscribe = onBackground(listener);
    phase("background");
    unsubscribe();
    unsubscribe();
    phase("active");
    phase("background");
    expect(listener).toHaveBeenCalledOnce();
  });

  it("passes memory warnings to every listener", () => {
    const first = vi.fn();
    const second = vi.fn();
    cleanups.push(onMemoryWarning(first), onMemoryWarning(second));
    globalThis.__svelteAppEvent("memorywarning", null);
    expect(first).toHaveBeenCalledOnce();
    expect(second).toHaveBeenCalledOnce();
  });

  it("parses opened URLs and skips ones that don't parse", () => {
    const opened: Array<string> = [];
    cleanups.push(
      onOpenURL((url) => {
        opened.push(
          `${url.protocol} ${url.pathname} ${url.searchParams.get("id")}`,
        );
      }),
    );
    globalThis.__svelteAppEvent("openurl", "sveltehost://todos/detail?id=4");
    globalThis.__svelteAppEvent("openurl", "not a url");
    globalThis.__svelteAppEvent("openurl", 42);
    expect(opened).toEqual(["sveltehost: /detail 4"]);
  });

  it("keeps calling other listeners when one throws", () => {
    const errors = vi.spyOn(console, "error").mockImplementation(() => {});
    const after = vi.fn();
    const failure = new Error("listener failed");
    cleanups.push(
      onMemoryWarning(() => {
        throw failure;
      }),
      onMemoryWarning(after),
    );
    const reported: Array<unknown> = [];
    vi.stubGlobal("reportError", (error: unknown) => {
      reported.push(error);
    });
    globalThis.__svelteAppEvent("memorywarning", null);
    vi.unstubAllGlobals();
    errors.mockRestore();
    expect(after).toHaveBeenCalledOnce();
    expect(reported).toEqual([failure]);
  });

  it("lets a listener unsubscribe while the event is being delivered", () => {
    const second = vi.fn();
    const unsubscribe = onMemoryWarning(() => unsubscribe());
    cleanups.push(onMemoryWarning(second));
    globalThis.__svelteAppEvent("memorywarning", null);
    globalThis.__svelteAppEvent("memorywarning", null);
    expect(second).toHaveBeenCalledTimes(2);
  });
});

describe("deep links", () => {
  it("holds links that arrive before anything listens", async () => {
    globalThis.__svelteAppEvent("openurl", "sveltehost://todos/7");
    const opened: Array<string> = [];
    cleanups.push(
      onOpenURL((url) => {
        opened.push(url.href);
      }),
    );
    expect(opened).toEqual([]);
    await Promise.resolve();
    expect(opened).toEqual(["sveltehost://todos/7"]);
    cleanups.push(
      onOpenURL((url) => {
        opened.push(`late ${url.href}`);
      }),
    );
    await Promise.resolve();
    expect(opened).toEqual(["sveltehost://todos/7"]);
  });

  it("matches custom schemes and web links against the same pattern", () => {
    expect(matchURL("todos/:id", "sveltehost://todos/2")).toEqual({ id: "2" });
    expect(matchURL("/todos/:id", "https://example.com/todos/2?x=1")).toEqual({
      id: "2",
    });
    expect(matchURL("todos", new URL("sveltehost://todos"))).toEqual({});
    expect(matchURL("todos/:id", "sveltehost://todos")).toBeNull();
    expect(matchURL("todos/:id", "sveltehost://todos/2/edit")).toBeNull();
    expect(matchURL("todos/:id", "sveltehost://notes/2")).toBeNull();
    expect(matchURL("notes/*", "sveltehost://notes/a/b%20c")).toEqual({
      "*": "a/b c",
    });
    expect(matchURL("tag/:name", "sveltehost://tag/%E0%A4%A")).toEqual({
      name: "%E0%A4%A",
    });
    expect(matchURL("todos/:id", "not a url")).toBeNull();
  });
});

describe("restorable", () => {
  it("restores saved state and saves every change", () => {
    vi.stubGlobal(
      "localStorage",
      createStorage([
        ["swiftui-svelte.restorable.stack", "[3,4]"],
        ["swiftui-svelte.restorable.tab", "42"],
        ["swiftui-svelte.restorable.broken", "{"],
      ]),
    );
    try {
      const stack = restorable<Array<number>>("stack", []);
      expect(stack.value).toEqual([3, 4]);
      expect(restorable<Array<number>>("stack", [])).toBe(stack);
      stack.value.push(5);
      flushSync();
      expect(localStorage.getItem("swiftui-svelte.restorable.stack")).toBe(
        "[3,4,5]",
      );
      expect(restorable("tab", "todos").value).toBe("todos");
      expect(restorable("broken", "fallback").value).toBe("fallback");
      const isIDs = (value: unknown): value is Array<number> =>
        Array.isArray(value) && value.every((item) => typeof item === "number");
      expect(restorable("fresh", [1], isIDs).value).toEqual([1]);
      flushSync();
      expect(localStorage.getItem("swiftui-svelte.restorable.fresh")).toBe(
        "[1]",
      );
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
