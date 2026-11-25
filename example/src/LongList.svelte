<script lang="ts">
  import { tick } from "svelte";
  import { ref } from "swiftui-svelte";
  import { nativeModule } from "swiftui-svelte/native";

  const { kind }: { kind: "list" | "lazyvstack" } = $props();
  const diagnostics = nativeModule("diagnostics");
  const rows = Array.from({ length: 10_000 }, (_, index) => index + 1);
  const marker = ref();
  let target = $state(0);
  let memory = $state("");
  let opened = "";
  let scrolling = $state(false);

  async function open() {
    opened = (await diagnostics.memory()).toFixed(1);
  }

  async function scrollThrough() {
    scrolling = true;
    const before = await diagnostics.memory();
    for (let row = 20; row <= 3000; row += 20) {
      target = row;
      await tick();
      marker.scrollIntoView({ anchor: "top", animated: false });
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
    const after = await diagnostics.memory();
    memory = `${opened} → ${before.toFixed(1)} → ${after.toFixed(1)} MB`;
    scrolling = false;
  }
</script>

{#snippet controls()}
  <safeareainset edge="bottom">
    <hstack padding background="thinMaterial">
      <btn disabled={scrolling} onclick={scrollThrough}>
        Scroll through 3,000 rows
      </btn>
      <spacer />
      <txt>{memory === "" ? "Not measured" : memory}</txt>
    </hstack>
  </safeareainset>
{/snippet}

<screen title="10,000 rows" titledisplaymode="inline">
  {#if kind === "list"}
    <list onappear={open}>
      {#each rows as row (row)}
        <txt {@attach row === target ? marker : undefined}>Row {row}</txt>
      {/each}
      {@render controls()}
    </list>
  {:else}
    <scrollview onappear={open}>
      <lazyvstack alignment="leading" spacing={12} padding>
        {#each rows as row (row)}
          <txt {@attach row === target ? marker : undefined}>Row {row}</txt>
        {/each}
      </lazyvstack>
      {@render controls()}
    </scrollview>
  {/if}
</screen>
