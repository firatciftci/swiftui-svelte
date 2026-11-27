import { flushSync } from "svelte";
import { mountApp } from "swiftui-svelte";
import * as bench from "../components/bench.svelte.ts";
import Table from "../components/Table.svelte";
import { run } from "./driver.ts";
import Shapes from "./Shapes.svelte";

mountApp({ Shapes, Table });

Object.assign(globalThis, {
  __jscBench: (count: number, rounds: number) =>
    run(count, rounds, (operation, size) =>
      flushSync(() => bench[operation](size)),
    ),
});
