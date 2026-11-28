import { readFileSync } from "node:fs";
import { expect, it, vi } from "vitest";
import "swiftui-svelte";
import { protocol, version } from "swiftui-svelte/protocol";
import { frame, native } from "./bridge.ts";

it("runs the other frame callbacks when one throws", () => {
  const reported: Array<unknown> = [];
  vi.stubGlobal("reportError", (error: unknown) => void reported.push(error));
  const times: Array<number> = [];
  requestAnimationFrame(() => {
    throw new Error("boom");
  });
  requestAnimationFrame((time) => void times.push(time));
  frame(7);
  vi.unstubAllGlobals();
  expect(times).toEqual([7]);
  expect(reported).toHaveLength(1);
});

it("runs animation frame callbacks once, with the frame time", () => {
  const times: Array<number> = [];
  requestAnimationFrame((time) => void times.push(time));
  requestAnimationFrame((time) => void times.push(time + 1));
  frame(100);
  frame(116);
  expect(times).toEqual([100, 101]);
});

it("asks for one native frame per batch of callbacks", () => {
  const before = native.frameRequests;
  requestAnimationFrame(() => {});
  requestAnimationFrame(() => {});
  expect(native.frameRequests - before).toBe(1);
  frame(0);
});

it("cancels a callback", () => {
  let didRun = false;
  cancelAnimationFrame(requestAnimationFrame(() => (didRun = true)));
  frame(0);
  expect(didRun).toBe(false);
});

it("runs callbacks requested during a frame on the next frame", () => {
  const times: Array<number> = [];
  const loop = (time: number): void => {
    times.push(time);
    if (times.length < 3) requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  frame(1);
  expect(times).toEqual([1]);
  frame(2);
  frame(3);
  frame(4);
  expect(times).toEqual([1, 2, 3]);
});

it("tells the host which release and protocol built the bundle", () => {
  expect(globalThis.__svelteBundle).toEqual({ version, protocol });
});

it("uses one version for the npm package and the Swift package", () => {
  const manifest = JSON.parse(readFileSync("package.json", "utf8")) as {
    version: string;
  };
  const swift = readFileSync("Sources/SvelteSwiftUI/Version.swift", "utf8");
  expect(version).toBe(manifest.version);
  expect(swift).toContain(`version = "${manifest.version}"`);
});
