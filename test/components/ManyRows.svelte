<script lang="ts">
  import { state } from "./state.svelte.ts";

  const { count }: { count: number } = $props();
  const rows = $derived(Array.from({ length: count }, (_, index) => index));
</script>

<vstack>
  {#if state.show}
    {#each rows as row (row)}
      <txt>{row}</txt>
    {/each}
  {/if}
</vstack>
