import { existsSync } from "node:fs";
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
import { benchmark, jsc } from "./jsc/run.ts";

type Budget = { ops: number; ms: number };

const operations = { create, update, swap, reverse, clear } satisfies Record<
  string,
  (count: number) => void
>;
const slack = import.meta.env.CI == null ? 1 : 3;
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
        expect
          .soft(result.ms, `${name} time`)
          .toBeLessThanOrEqual(limit.ms * slack);
      }
      stop();
    }, 120_000);
  }
});

type RowBudget = [
  bytes: number,
  mount: number,
  update: number,
  swap: number,
  unmount: number,
];

const retainedBudget = 160;
const rowBudgets: Record<string, RowBudget> = {
  "each-empty": [630, 3, 2, 1, 1],
  "txt-static": [900, 8, 2, 1, 1],
  txt: [1590, 12, 5, 1, 2],
  "vstack-txt": [1710, 15, 5, 1, 2],
  attrs: [2100, 21, 5, 1, 2],
  class: [1800, 22, 5, 1, 2],
  snippet: [1730, 13, 5, 1, 2],
  pass: [3680, 25, 6, 1, 3],
  props: [3680, 28, 6, 1, 3],
  "hover-plain": [4180, 30, 5, 1, 3],
  hover: [5200, 38, 5, 1, 4],
  btn: [2100, 17, 5, 1, 2],
  table: [4160, 65, 2, 4, 4],
};

describe.skipIf(!existsSync(jsc))(
  "rows in JavaScriptCore without the JIT",
  () => {
    it("keeps every row shape within its memory and time budgets", async () => {
      const report = await benchmark();
      for (const [shape, [bytes, ...times]] of Object.entries(rowBudgets)) {
        const sample = report[shape];
        expect(sample, shape).toBeDefined();
        if (sample == null) continue;
        expect
          .soft(sample.bytes, `${shape} bytes per row`)
          .toBeLessThanOrEqual(bytes);
        expect
          .soft(sample.retained, `${shape} bytes per row after unmounting`)
          .toBeLessThanOrEqual(retainedBudget);
        const phases = ["mount", "update", "swap", "unmount"] as const;
        for (const [index, phase] of phases.entries()) {
          expect
            .soft(sample[phase], `${shape} ${phase} time`)
            .toBeLessThanOrEqual((times[index] ?? 0) * slack);
        }
      }
    }, 300_000);
  },
);
