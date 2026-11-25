import { flushSync } from "svelte";
import { afterEach, beforeEach, expect, it } from "vitest";
import { mountApp } from "swiftui-svelte";
import { findAll, reset, settle } from "./bridge.ts";
import Items from "./components/Items.svelte";
import { resetState, state } from "./components/state.svelte.ts";

function random(seed: number): () => number {
  let value = seed;
  return () => {
    value = (value * 1_103_515_245 + 12_345) % 2_147_483_648;
    return value / 2_147_483_648;
  };
}

let unmount: (() => void) | undefined;

beforeEach(() => {
  reset();
  resetState();
});

afterEach(() => unmount?.());

it.each([1, 2, 3, 4, 5, 6, 7, 8])(
  "keeps native rows in order through random edits (seed %i)",
  async (seed) => {
    const next = random(seed);
    let nextItem = 100;
    unmount = mountApp(Items);
    flushSync();
    await settle();
    for (let step = 0; step < 200; step++) {
      const roll = next();
      const items = state.items;
      const index = Math.floor(next() * (items.length + 1));
      if (roll < 0.3) items.splice(index, 0, nextItem++);
      else if (roll < 0.5 && items.length > 0)
        items.splice(Math.min(index, items.length - 1), 1);
      else if (roll < 0.7 && items.length > 1) {
        const [moved] = items.splice(Math.min(index, items.length - 1), 1);
        if (moved != null)
          items.splice(Math.floor(next() * (items.length + 1)), 0, moved);
      } else if (roll < 0.8) items.reverse();
      else if (roll < 0.9) items.sort(() => next() - 0.5);
      else if (roll < 0.95) state.items = [];
      else
        state.items = Array.from(
          { length: Math.floor(next() * 20) },
          () => nextItem++,
        );
      flushSync();
      await settle();
      expect(
        findAll("txt").map((node) => Number(node.children[0]?.text)),
      ).toEqual(state.items);
    }
  },
);
