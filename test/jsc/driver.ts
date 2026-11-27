import { stats } from "swiftui-svelte";
import type { Row } from "./rows.svelte.ts";
import { show } from "./rows.svelte.ts";

declare function fullGC(): void;
declare function gcHeapSize(): number;
declare function drainMicrotasks(): void;
declare function preciseTime(): number;
declare function print(...values: Array<unknown>): void;

export type Sample = {
  nodes: number;
  bytes: number;
  retained: number;
  mount: number;
  update: number;
  swap: number;
  unmount: number;
};

export const shapes = [
  "each-empty",
  "txt-static",
  "txt",
  "vstack-txt",
  "attrs",
  "class",
  "snippet",
  "pass",
  "props",
  "hover-plain",
  "hover",
  "btn",
  "table",
] as const;

type Operation = "create" | "update" | "swap" | "clear";

Object.assign(globalThis, {
  __nativeCommit: () => {},
  __nativeNow: () => preciseTime() * 1000,
  __nativeInvoke: () => {},
  __nativeRequestFrame: () => {},
  __nativeAction: () => {},
  __nativeLog: (level: string, message: string) =>
    print(`${level}: ${message}`),
});

function settle(): void {
  for (let round = 0; round < 5; round++) drainMicrotasks();
}

function heap(): number {
  for (let round = 0; round < 3; round++) {
    fullGC();
    settle();
  }
  return gcHeapSize();
}

function time(change: () => void): number {
  const start = preciseTime();
  change();
  settle();
  return (preciseTime() - start) * 1000;
}

function rows(count: number, suffix: string): Array<Row> {
  const items = new Array<Row>();
  for (let id = 0; id < count; id++)
    items.push({ id, label: `Row ${id}${suffix}` });
  return items;
}

function swapped(items: Array<Row>): Array<Row> {
  const end = items.length - 2;
  const second = items[1];
  const last = items[end];
  if (second == null || last == null) return items;
  return items.with(1, last).with(end, second);
}

const mounts = { next: 1 };

function mount(name: string, props: Record<string, unknown>): number {
  const id = mounts.next++;
  __svelteMount(id, name, JSON.stringify({ props, actions: [] }));
  return id;
}

function measureShape(shape: string, count: number): Sample {
  show(rows(count, ""));
  const before = heap();
  const created = stats.live;
  let id = 0;
  const mounted = time(() => {
    id = mount("Shapes", { shape });
  });
  const nodes = (stats.live - created) / count;
  const bytes = (heap() - before) / count;
  const next = rows(count, " !");
  const update = time(() => show(next));
  const swap = time(() => show(swapped(next)));
  const unmount = time(() => __svelteUnmount(id));
  const retained = (heap() - before) / count;
  show([]);
  return { nodes, bytes, retained, mount: mounted, update, swap, unmount };
}

function measureTable(
  count: number,
  table: (operation: Operation, count: number) => void,
): Sample {
  const id = mount("Table", {});
  settle();
  const before = heap();
  const created = stats.live;
  const mounted = time(() => table("create", count));
  const nodes = (stats.live - created) / count;
  const bytes = (heap() - before) / count;
  const update = time(() => table("update", count));
  const swap = time(() => table("swap", count));
  const unmount = time(() => table("clear", count));
  const retained = (heap() - before) / count;
  __svelteUnmount(id);
  settle();
  return { nodes, bytes, retained, mount: mounted, update, swap, unmount };
}

function median(values: Array<number>): number {
  const sorted = values.toSorted((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? 0;
}

export function run(
  count: number,
  rounds: number,
  table: (operation: Operation, count: number) => void,
): Record<string, Sample> {
  const report: Record<string, Sample> = {};
  for (const shape of shapes) {
    const samples = new Array<Sample>();
    for (let round = 0; round <= rounds; round++) {
      const sample =
        shape === "table"
          ? measureTable(count, table)
          : measureShape(shape, count);
      if (round > 0) samples.push(sample);
    }
    report[shape] = {
      nodes: median(samples.map((sample) => sample.nodes)),
      bytes: Math.round(median(samples.map((sample) => sample.bytes))),
      retained: Math.round(median(samples.map((sample) => sample.retained))),
      mount: median(samples.map((sample) => sample.mount)),
      update: median(samples.map((sample) => sample.update)),
      swap: median(samples.map((sample) => sample.swap)),
      unmount: median(samples.map((sample) => sample.unmount)),
    };
  }
  return report;
}
