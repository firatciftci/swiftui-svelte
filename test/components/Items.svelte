<script lang="ts">
  import { state } from "./state.svelte.ts";
</script>

<list padding={state.padding}>
  {#each state.items as item (item)}
    <txt>{item}</txt>
  {/each}
</list>
{#if state.show}
  <divider />
{:else}
  <spacer />
{/if}
