<script lang="ts">
  import { state } from "./state.svelte.ts";

  const { count }: { count: number } = $props();
  const rows = $derived(Array.from({ length: count }, (_, index) => index));
</script>

<vstack>
  {#each rows as row (row)}
    {#if state.show}
      <txt>{row}</txt>
    {/if}
  {/each}
</vstack>
