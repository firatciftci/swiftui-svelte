<script lang="ts">
  import { table } from "./bench.svelte.ts";

  let selected = $state(0);
</script>

<list>
  {#each table.rows as row (row.id)}
    <hstack>
      <txt weight={selected === row.id ? "bold" : "regular"}>{row.label}</txt>
      <btn onclick={() => (selected = row.id)}>Select</btn>
    </hstack>
  {/each}
</list>
