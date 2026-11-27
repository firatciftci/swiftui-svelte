import { existsSync } from "node:fs";
import { flushSync } from "svelte";
import { describe, expect, it } from "vitest";
import { stats } from "swiftui-svelte";
import type { Sample } from "./jsc/run.ts";
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

const rowBudgets: Record<string, Omit<Sample, "nodes">> = {
  "each-empty": {
    bytes: 627,
    retained: 64,
    mount: 3,
    update: 2,
    swap: 1,
    unmount: 1,
  },
  "txt-static": {
    bytes: 1137,
    retained: 256,
    mount: 9,
    update: 2,
    swap: 1,
    unmount: 2,
  },
  txt: { bytes: 1830, retained: 64, mount: 14, update: 6, swap: 1, unmount: 2 },
  "vstack-txt": {
    bytes: 2200,
    retained: 96,
    mount: 18,
    update: 6,
    swap: 1,
    unmount: 2,
  },
  attrs: {
    bytes: 2869,
    retained: 96,
    mount: 25,
    update: 6,
    swap: 1,
    unmount: 2,
  },
  class: {
    bytes: 2587,
    retained: 128,
    mount: 33,
    update: 6,
    swap: 1,
    unmount: 2,
  },
  snippet: {
    bytes: 1971,
    retained: 64,
    mount: 15,
    update: 6,
    swap: 1,
    unmount: 2,
  },
  pass: {
    bytes: 3925,
    retained: 64,
    mount: 28,
    update: 6,
    swap: 1,
    unmount: 3,
  },
  props: {
    bytes: 3925,
    retained: 64,
    mount: 32,
    update: 7,
    swap: 1,
    unmount: 3,
  },
  "hover-plain": {
    bytes: 5280,
    retained: 96,
    mount: 33,
    update: 6,
    swap: 1,
    unmount: 3,
  },
  hover: {
    bytes: 6512,
    retained: 96,
    mount: 42,
    update: 6,
    swap: 1,
    unmount: 4,
  },
  btn: { bytes: 3203, retained: 96, mount: 20, update: 6, swap: 1, unmount: 2 },
  table: {
    bytes: 5475,
    retained: 128,
    mount: 72,
    update: 3,
    swap: 4,
    unmount: 5,
  },
};

describe.skipIf(!existsSync(jsc))(
  "rows in JavaScriptCore without the JIT",
  () => {
    it("keeps every row shape within its memory and time budgets", async () => {
      const report = await benchmark();
      for (const [shape, budget] of Object.entries(rowBudgets)) {
        const sample = report[shape];
        expect(sample, shape).toBeDefined();
        if (sample == null) continue;
        expect
          .soft(sample.bytes, `${shape} bytes per row`)
          .toBeLessThanOrEqual(budget.bytes);
        expect
          .soft(sample.retained, `${shape} bytes per row after unmounting`)
          .toBeLessThanOrEqual(budget.retained);
        for (const phase of ["mount", "update", "swap", "unmount"] as const) {
          expect
            .soft(sample[phase], `${shape} ${phase} time`)
            .toBeLessThanOrEqual(budget[phase] * slack);
        }
      }
    }, 300_000);
  },
);
