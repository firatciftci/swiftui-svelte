import { existsSync } from "node:fs";
import process from "node:process";
import { benchmark, jsc } from "../test/jsc/run.ts";

if (!existsSync(jsc))
  throw new Error(`There's no JavaScriptCore shell at ${jsc}.`);

const count = 1000;
const report = await benchmark({ count });
const rows = [
  [
    "shape",
    "created",
    "B/row",
    "retained",
    "mount ms",
    "update ms",
    "swap ms",
    "unmount ms",
  ],
];
for (const [shape, sample] of Object.entries(report)) {
  rows.push([
    shape,
    sample.nodes.toFixed(1),
    String(sample.bytes),
    String(sample.retained),
    sample.mount.toFixed(2),
    sample.update.toFixed(2),
    sample.swap.toFixed(2),
    sample.unmount.toFixed(2),
  ]);
}
process.stdout.write(
  `JavaScriptCore without the JIT, ${count} rows, median bytes and fastest time of 5 runs\n`,
);
for (const row of rows) {
  const cells = row.map((cell, index) =>
    index === 0 ? cell.padEnd(12) : cell.padStart(10),
  );
  process.stdout.write(`${cells.join(" ")}\n`);
}
