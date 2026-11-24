<script lang="ts">
  import { flushSync, onMount } from "svelte";
  import { stats } from "#renderer";

  const ROWS = 1000;

  let rows = $state<Array<{ id: number; label: string; done: boolean }>>([]);
  let text = $state("");
  let status = $state("Starting");
  let field: { id: number } | undefined;
  let nextId = 1;

  const wait = (ms: number) =>
    new Promise<void>((resolve) => setTimeout(resolve, ms));
  const ms = (value: number) => `${value.toFixed(1)}ms`;

  function makeRows(count: number) {
    const created: typeof rows = [];
    for (let index = 0; index < count; index++) {
      const id = nextId++;
      created.push({ id, label: `Row ${id}`, done: id % 3 === 0 });
    }
    return created;
  }

  async function measure(name: string, change: () => void) {
    status = name;
    await wait(400);
    __nativeStats();
    const before = { ...stats };
    const start = __nativeNow();
    flushSync(change);
    const svelte = __nativeNow() - start;
    await wait(600);
    const native = __nativeStats();
    console.log(
      [
        `BENCH ${name.padEnd(12)}`,
        `svelte=${ms(svelte)}`,
        `serialize=${ms(stats.serializeMs - before.serializeMs)}`,
        `native=${ms(stats.nativeMs - before.nativeMs)}`,
        `ops=${stats.ops - before.ops}`,
        `kb=${((stats.bytes - before.bytes) / 1024).toFixed(0)}`,
        `maxFrame=${ms(native.maxFrameGapMs)}`,
      ].join(" "),
    );
  }

  async function typing() {
    status = "typing";
    await wait(400);
    __nativeStats();
    const latencies: Array<number> = [];
    for (const character of "swiftui-svelte") {
      const start = __nativeNow();
      if (field != null) __svelteDispatch(field.id, "input", text + character);
      await wait(0);
      latencies.push(stats.lastCommitEnd - start);
      await wait(50);
    }
    latencies.sort((a, b) => a - b);
    const native = __nativeStats();
    console.log(
      [
        `BENCH ${"typing".padEnd(12)}`,
        `median=${ms(latencies[Math.floor(latencies.length / 2)] ?? 0)}`,
        `max=${ms(latencies.at(-1) ?? 0)}`,
        `maxFrame=${ms(native.maxFrameGapMs)}`,
      ].join(" "),
    );
  }

  async function churn() {
    status = "churn";
    for (let round = 0; round < 5; round++) {
      flushSync(() => (rows = makeRows(ROWS)));
      await wait(150);
      flushSync(() => (rows = []));
      await wait(150);
    }
    for (let round = 0; round < 6; round++) {
      __nativeGC();
      const garbage: Array<Array<number>> = [];
      for (let index = 0; index < 200; index++)
        garbage.push(new Array(10_000).fill(index));
      await wait(500);
    }
    console.log(
      `BENCH ${"churn".padEnd(12)} created=${nextId - 1} rows, live-js=${stats.live} native-nodes=${__nativeStats().nodes}`,
    );
  }

  function cpu() {
    const start = __nativeNow();
    let value = 0;
    for (let index = 0; index < 5_000_000; index++) {
      value = (value + index * 7) % 1_000_003;
    }
    console.log(
      `BENCH ${"cpu-loop".padEnd(12)} ${ms(__nativeNow() - start)} (${value})`,
    );
  }

  onMount(() => {
    void (async () => {
      await wait(1000);
      cpu();
      await measure("create", () => (rows = makeRows(ROWS)));
      await measure("update-all", () => {
        for (const row of rows) row.label += "!";
      });
      await measure("update-one", () => {
        const row = rows[Math.floor(rows.length / 2)];
        if (row != null) row.label = "Changed";
      });
      await measure("toggle-all", () => {
        for (const row of rows) row.done = !row.done;
      });
      await measure("reverse", () => rows.reverse());
      await measure("append-one", () => rows.push(...makeRows(1)));
      await typing();
      await measure("clear", () => (rows = []));
      await churn();
      status = "Done";
      console.log("BENCH done");
    })();
  });
</script>

<navstack>
  <screen title="Benchmark">
    <list>
      <txt font="headline">{status}</txt>
      <textfield
        value={text}
        oninput={(value) => (text = value)}
        {@attach (node: { id: number }) => {
          field = node;
        }}
      />
      {#each rows as row (row.id)}
        <hstack>
          <txt>{row.label}</txt>
          <spacer />
          <toggle
            checked={row.done}
            onchange={(checked) => (row.done = checked)}
          />
        </hstack>
      {/each}
    </list>
  </screen>
</navstack>
