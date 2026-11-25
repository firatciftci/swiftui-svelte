import { flushSync } from "svelte";
import { describe, expect, it } from "vitest";
import { stats } from "swiftui-svelte";
import { mountComponent, settle } from "./bridge.ts";
import {
  clear,
  create,
  reverse,
  swap,
  update,
} from "./components/bench.svelte.ts";
import Table from "./components/Table.svelte";

type Budget = { ops: number; ms: number };

const operations = { create, update, swap, reverse, clear } satisfies Record<
  string,
  (count: number) => void
>;
const names = ["create", "update", "swap", "reverse", "clear"] as const;

const budgets: Record<number, Record<(typeof names)[number], Budget>> = {
  1000: {
    create: { ops: 1004, ms: 150 },
    update: { ops: 100, ms: 25 },
    swap: { ops: 2, ms: 25 },
    reverse: { ops: 999, ms: 250 },
    clear: { ops: 1000, ms: 40 },
  },
  10_000: {
    create: { ops: 10_000, ms: 2500 },
    update: { ops: 1000, ms: 120 },
    swap: { ops: 2, ms: 400 },
    reverse: { ops: 9999, ms: 15_000 },
    clear: { ops: 10_000, ms: 400 },
  },
};

async function measure(change: () => void): Promise<Budget> {
  const before = stats.ops;
  const start = performance.now();
  flushSync(change);
  await settle();
  return { ops: stats.ops - before, ms: performance.now() - start };
}

describe("benchmarks", () => {
  for (const [count, budget] of Object.entries(budgets)) {
    it(`keeps ${count} rows within budget`, async () => {
      const stop = mountComponent(Table);
      flushSync();
      await settle();
      for (const name of names) {
        const limit = budget[name];
        const result = await measure(() => operations[name](Number(count)));
        expect.soft(result.ops, `${name} ops`).toBeLessThanOrEqual(limit.ops);
        expect.soft(result.ms, `${name} time`).toBeLessThanOrEqual(limit.ms);
      }
      stop();
    }, 120_000);
  }
});
