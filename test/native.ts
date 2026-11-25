import { flushSync } from "svelte";
import { mountApp } from "swiftui-svelte";
import * as bench from "./components/bench.svelte.ts";
import Counter from "./components/Counter.svelte";
import Greeting from "./components/Greeting.svelte";
import Table from "./components/Table.svelte";

mountApp({ Counter, Greeting, Table });

Object.assign(globalThis, {
  __bench: (name: keyof typeof bench, count: number) => {
    const operation = bench[name];
    if (typeof operation === "function") flushSync(() => operation(count));
  },
});
