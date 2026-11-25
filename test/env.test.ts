import { flushSync } from "svelte";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { Environment } from "swiftui-svelte/env";
import { env } from "swiftui-svelte/env";
import { byTestId, mountComponent, reset, settle } from "./bridge.ts";
import Env from "./components/Env.svelte";
import { effects } from "./components/state.svelte.ts";

const defaults: Environment = { ...env, languages: [...env.languages] };

let unmount: (() => void) | undefined;

function text(id: string): string | undefined {
  return byTestId(id)?.children[0]?.text;
}

async function host(changes: Partial<Environment>): Promise<void> {
  globalThis.__svelteEnvironment(JSON.stringify(changes));
  flushSync();
  await settle();
}

beforeEach(async () => {
  reset();
  effects.length = 0;
  unmount = mountComponent(Env);
  flushSync();
  await settle();
});

afterEach(async () => {
  unmount?.();
  unmount = undefined;
  await host(defaults);
});

describe("swiftui-svelte/env", () => {
  it("starts with the host's values", () => {
    expect(text("scheme")).toBe("light");
    expect(text("size")).toBe("large");
    expect(text("insets")).toBe("0,0");
    expect(text("keyboard")).toBe("0");
    expect(byTestId("wide")).toBeUndefined();
  });

  it("updates the screen when the host reports a change", async () => {
    await host({
      colorScheme: "dark",
      dynamicTypeSize: "accessibility2",
      safeAreaInsets: { top: 59, leading: 0, bottom: 34, trailing: 0 },
      keyboardHeight: 336,
      horizontalSizeClass: "regular",
    });
    expect(text("scheme")).toBe("dark");
    expect(text("size")).toBe("accessibility2");
    expect(text("insets")).toBe("59,34");
    expect(text("keyboard")).toBe("336");
    expect(text("wide")).toBe("wide");
  });

  it("reruns only the effects that read a changed value", async () => {
    expect(effects).toEqual(["light", "insets 0"]);
    await host({ keyboardHeight: 300, scenePhase: "inactive" });
    expect(effects).toEqual(["light", "insets 0"]);
    await host({ colorScheme: "dark" });
    expect(effects).toEqual(["light", "insets 0", "dark"]);
    await host({ colorScheme: "dark" });
    expect(effects).toEqual(["light", "insets 0", "dark"]);
  });

  it("ignores insets that arrive as a new but equal object", async () => {
    await host({
      safeAreaInsets: { top: 0, leading: 0, bottom: 0, trailing: 0 },
    });
    expect(effects).toEqual(["light", "insets 0"]);
    await host({
      safeAreaInsets: { top: 47, leading: 0, bottom: 0, trailing: 0 },
    });
    expect(effects).toEqual(["light", "insets 0", "insets 47"]);
  });

  it("reads the current value outside components", async () => {
    await host({ locale: "ar-EG", layoutDirection: "rightToLeft" });
    expect(env.locale).toBe("ar-EG");
    expect(env.layoutDirection).toBe("rightToLeft");
  });
});
