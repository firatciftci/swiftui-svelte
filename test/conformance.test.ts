import { flushSync } from "svelte";
import { expect, it } from "vitest";
import {
  commits,
  dispatch,
  find,
  findAll,
  mountComponent,
  serialize,
  settle,
} from "./bridge.ts";
import Counter from "./components/Counter.svelte";
import Items from "./components/Items.svelte";
import { state } from "./components/state.svelte.ts";
import Texts from "./components/Texts.svelte";
import Values from "./components/Values.svelte";

declare const process: {
  cwd: () => string;
  getBuiltinModule: (name: "node:fs") => {
    writeFileSync: (path: string, data: string) => void;
  };
};

type Step = { label: string; commits: Array<string>; tree: string };

const steps: Array<Step> = [];
let recorded = 0;

async function step(label: string, change: () => void): Promise<void> {
  change();
  flushSync();
  await settle();
  const fresh = commits.slice(recorded);
  recorded = commits.length;
  steps.push({ label, commits: fresh, tree: serialize() });
}

function noop(): void {}

function random(seed: number): () => number {
  let value = seed;
  return () => {
    value = (value * 1_103_515_245 + 12_345) % 2_147_483_648;
    return value / 2_147_483_648;
  };
}

it("records op logs that the Swift tests replay", async () => {
  let unmount = noop;

  await step("Counter: mount", () => (unmount = mountComponent(Counter)));
  await step("Counter: click twice", () => {
    dispatch(find("btn"), "click");
    dispatch(find("btn"), "click");
  });
  await step("Counter: type a name", () =>
    dispatch(find("textfield"), "input", 'Ada "Lovelace" ✨'),
  );
  await step("Counter: clear the name", () =>
    dispatch(find("textfield"), "input", ""),
  );
  await step("Counter: unmount", () => unmount());

  await step("Items: mount", () => (unmount = mountComponent(Items)));
  await step("Items: reverse", () => state.items.reverse());
  await step("Items: splice, push, and unshift", () => {
    state.items.splice(1, 1);
    state.items.push(4, 5);
    state.items.unshift(0);
  });
  await step("Items: swap branches", () => (state.show = false));
  await step("Items: remove padding", () => (state.padding = undefined));
  const next = random(42);
  let nextItem = 100;
  for (let index = 0; index < 40; index++) {
    await step(`Items: random edit ${index}`, () => {
      const items = state.items;
      const roll = next();
      const at = Math.floor(next() * (items.length + 1));
      if (roll < 0.35) items.splice(at, 0, nextItem++);
      else if (roll < 0.55 && items.length > 0)
        items.splice(Math.min(at, items.length - 1), 1);
      else if (roll < 0.8 && items.length > 1) {
        const [moved] = items.splice(Math.min(at, items.length - 1), 1);
        if (moved != null)
          items.splice(Math.floor(next() * (items.length + 1)), 0, moved);
      } else items.reverse();
    });
    expect(
      findAll("txt").map((node) => Number(node.children[0]?.text)),
    ).toEqual(state.items);
  }
  await step("Items: unmount", () => unmount());

  await step("Values: mount", () => (unmount = mountComponent(Values)));
  await step("Values: unmount", () => unmount());

  await step("Texts: mount", () => (unmount = mountComponent(Texts)));
  await step(
    "Texts: show a label",
    () => (state.label = 'Hi \\ "there" \n 😀'),
  );
  await step("Texts: blank the label", () => (state.label = " "));
  await step("Texts: unmount", () => unmount());

  const fs = process.getBuiltinModule("node:fs");
  fs.writeFileSync(
    `${process.cwd()}/conformance/renderer.json`,
    `${JSON.stringify({ steps }, null, 2)}\n`,
  );
});
