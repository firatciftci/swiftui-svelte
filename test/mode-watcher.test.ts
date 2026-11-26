import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  mode,
  modeStorageKey,
  ModeWatcher,
  resetMode,
  setMode,
  systemPrefersMode,
  toggleMode,
  userPrefersMode,
} from "swiftui-svelte/mode-watcher";
import { updateEnvironment } from "swiftui-svelte/web/environment";
import { mountComponent, reset } from "./bridge.ts";

beforeEach(() => {
  localStorage.clear();
  updateEnvironment({ systemColorScheme: "light", colorScheme: "light" });
  setMode("system");
});

afterEach(() => {
  reset();
  vi.unstubAllGlobals();
});

describe("mode-watcher", () => {
  it("starts from the system preference", () => {
    expect(userPrefersMode.current).toBe("system");
    updateEnvironment({ systemColorScheme: "dark" });
    expect(systemPrefersMode.current).toBe("dark");
    expect(mode.current).toBe("dark");
  });

  it("persists the user's choice and reads it back", () => {
    setMode("light");
    expect(localStorage.getItem(modeStorageKey)).toBe("light");
    expect(mode.current).toBe("light");
  });

  it("toggles between light and dark from the resolved mode", () => {
    toggleMode();
    expect(userPrefersMode.current).toBe("dark");
    toggleMode();
    expect(userPrefersMode.current).toBe("light");
  });

  it("returns to the system preference", () => {
    setMode("dark");
    resetMode();
    expect(userPrefersMode.current).toBe("system");
  });

  it("reads and writes the storage key and default mode it's given", () => {
    vi.stubGlobal("__nativeInvoke", vi.fn());
    localStorage.setItem("themePreference", "dark");
    const stop = mountComponent(ModeWatcher, {
      modeStorageKey: "themePreference",
      defaultMode: "light",
    });
    flushSync();
    expect(userPrefersMode.current).toBe("dark");
    setMode("light");
    expect(localStorage.getItem("themePreference")).toBe("light");
    localStorage.removeItem("themePreference");
    stop();
    const fallback = mountComponent(ModeWatcher, {
      modeStorageKey: "themePreference",
      defaultMode: "dark",
    });
    flushSync();
    expect(userPrefersMode.current).toBe("dark");
    fallback();
    const defaults = mountComponent(ModeWatcher);
    flushSync();
    defaults();
  });

  it("sends the preference to the host's color scheme", () => {
    const invoke = vi.fn();
    vi.stubGlobal("__nativeInvoke", invoke);
    setMode("dark");
    const stop = mountComponent(ModeWatcher);
    flushSync();
    expect(invoke).toHaveBeenLastCalledWith(
      0,
      "colorScheme",
      JSON.stringify({ value: "dark" }),
    );
    setMode("light");
    flushSync();
    expect(invoke).toHaveBeenLastCalledWith(
      0,
      "colorScheme",
      JSON.stringify({ value: "light" }),
    );
    stop();
  });
});
