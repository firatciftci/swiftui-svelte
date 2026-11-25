import { flushSync } from "svelte";
import { expect, it } from "vitest";
import { stats } from "swiftui-svelte";
import { mountComponent, native, settle } from "./bridge.ts";
import Rows from "./components/Rows.svelte";

declare const gc: () => void;

async function collect(): Promise<void> {
  for (let round = 0; round < 10; round++) {
    gc();
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

function count(node: typeof native.root): number {
  if (node == null) return 0;
  let total = 1;
  for (const child of node.children) total += count(child);
  return total;
}

it("releases every node after mounting and unmounting 10,000 elements", async () => {
  await collect();
  const baseline = stats.live;
  for (let round = 0; round < 3; round++) {
    const stop = mountComponent(Rows, { count: 2500 });
    flushSync();
    await settle();
    expect(count(native.root)).toBeGreaterThan(10_000);
    expect(stats.live - baseline).toBeGreaterThan(10_000);
    stop();
    flushSync();
    await settle();
    expect(count(native.root)).toBe(0);
  }
  await collect();
  expect(stats.live - baseline).toBeLessThan(50);
});
