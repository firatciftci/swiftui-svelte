import { expect, it } from "vitest";
import "swiftui-svelte";
import { frame, native } from "./bridge.ts";

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
