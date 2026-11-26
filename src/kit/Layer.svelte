<script lang="ts">
  import type { Layer as LayerNode } from "./router.svelte.ts";
  import Layer from "./Layer.svelte";

  const { chain, index = 0 }: { chain: Array<LayerNode>; index?: number } =
    $props();
  const layer = $derived(chain[index]);
</script>

{#if layer?.kind === "layout"}
  <layer.component data={layer.data} params={layer.params}>
    <Layer {chain} index={index + 1} />
  </layer.component>
{:else if layer?.kind === "page"}
  <layer.component data={layer.data} params={layer.params} />
{:else if layer?.kind === "error"}
  {#if layer.component != null}
    <layer.component />
  {:else}
    <vstack>
      <spacer></spacer>
      <txt font="largeTitle" weight="bold">{layer.status}</txt>
      <txt color="secondary">{layer.message}</txt>
      <spacer></spacer>
    </vstack>
  {/if}
{/if}
