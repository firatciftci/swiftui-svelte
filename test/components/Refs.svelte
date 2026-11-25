<script lang="ts">
  import { field, list } from "./refs.ts";
  import { state } from "./state.svelte.ts";
</script>

<list testid="list" {@attach list}>
  {#each state.items as item (item)}
    <txt>{item}</txt>
  {/each}
</list>
{#if state.show}
  <textfield testid="field" {@attach field} />
{/if}
