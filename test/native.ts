import { flushSync } from "svelte";
import { mountApp } from "swiftui-svelte";
import * as bench from "./components/bench.svelte.ts";
import Counter from "./components/Counter.svelte";
import Greeting from "./components/Greeting.svelte";
import Table from "./components/Table.svelte";
import Tally from "./components/Tally.svelte";

mountApp({ Counter, Greeting, Table, Tally });

Object.assign(globalThis, {
  __bench: (name: keyof typeof bench, count: number) => {
    const operation = bench[name];
    if (typeof operation === "function") flushSync(() => operation(count));
  },
});
