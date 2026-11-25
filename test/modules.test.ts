import { afterEach, describe, expect, it, vi } from "vitest";
import {
  files,
  haptics,
  links,
  NativeError,
  nativeModule,
  secureStorage,
  share,
} from "swiftui-svelte/native";

type Call = { id: number; module: string; method: string; args: unknown };

const calls: Array<Call> = [];

function stubHost(): void {
  vi.stubGlobal(
    "__nativeCall",
    (id: number, module: string, method: string, json: string) => {
      calls.push({ id, module, method, args: JSON.parse(json) as unknown });
    },
  );
}

function last(): Call {
  const call = calls.at(-1);
  if (call == null) throw new Error("no native call");
  return call;
}

afterEach(() => {
  calls.length = 0;
  vi.unstubAllGlobals();
});

declare module "swiftui-svelte/native" {
  interface NativeModules {
    weather: {
      forecast: (city: string, days: number) => Promise<Array<number>>;
    };
  }
  interface NativeEvents {
    weather: { alert: { level: number } };
  }
}

describe("swiftui-svelte/native", () => {
  it("calls a native function and resolves with its result", async () => {
    stubHost();
    const weather = nativeModule("weather");
    const forecast = weather.forecast("Chicago", 3);
    expect(last()).toMatchObject({
      module: "weather",
      method: "forecast",
      args: ["Chicago", 3],
    });
    globalThis.__svelteNativeReply(last().id, null, "[21,19,24]");
    await expect(forecast).resolves.toEqual([21, 19, 24]);
  });

  it("rejects with the code and message that Swift throws", async () => {
    stubHost();
    const result = nativeModule("weather").forecast("Atlantis", 1);
    globalThis.__svelteNativeReply(
      last().id,
      JSON.stringify({ code: "notFound", message: "No such city" }),
      null,
    );
    await expect(result).rejects.toBeInstanceOf(NativeError);
    await expect(result).rejects.toMatchObject({
      code: "notFound",
      message: "No such city",
    });
  });

  it("rejects when there's no native host", async () => {
    await expect(haptics.selection()).rejects.toMatchObject({
      code: "unavailable",
    });
  });

  it("delivers native events to listeners until they unsubscribe", () => {
    const levels: Array<number> = [];
    const stop = nativeModule("weather").on("alert", (alert) => {
      levels.push(alert.level);
    });
    globalThis.__svelteNativeEvent("weather", "alert", '{"level":2}');
    globalThis.__svelteNativeEvent("weather", "other", '{"level":9}');
    stop();
    globalThis.__svelteNativeEvent("weather", "alert", '{"level":3}');
    expect(levels).toEqual([2]);
  });

  it("ignores replies to calls it doesn't know", () => {
    expect(() => globalThis.__svelteNativeReply(999, null, "1")).not.toThrow();
  });

  it("sends the arguments that the built-in modules expect", () => {
    stubHost();
    void haptics.impact({ style: "light" });
    expect(last()).toMatchObject({
      module: "haptics",
      method: "impact",
      args: [{ style: "light" }],
    });
    void share({ text: "Hi", url: new URL("https://svelte.dev") });
    expect(last().args).toEqual([{ text: "Hi", url: "https://svelte.dev/" }]);
    void links.open(new URL("tel:123"));
    expect(last()).toMatchObject({ module: "links", args: ["tel:123"] });
    void secureStorage.set("token", "abc");
    expect(last()).toMatchObject({
      module: "secureStorage",
      method: "set",
      args: ["token", "abc"],
    });
    void files.list();
    expect(last()).toMatchObject({ module: "files", args: [""] });
  });
});
