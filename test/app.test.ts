import { afterEach, describe, expect, it, vi } from "vitest";
import {
  onActive,
  onBackground,
  onInactive,
  onMemoryWarning,
  onOpenURL,
} from "swiftui-svelte/app";
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
