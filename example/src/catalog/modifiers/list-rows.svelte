<script lang="ts">
  import { move } from "swiftui-svelte";

  let rows = $state(["Pinned", "Second", "Third", "Fourth"]);
  let selected = $state<string | number | null>(null);
</script>

<list
  selection={selected}
  onselectionchange={(tag) => (selected = tag)}
  ondelete={(indices) =>
    (rows = rows.filter((_, index) => !indices.includes(index)))}
  onmove={({ from, to }) => move(rows, from, to)}
>
  {#each rows as row (row)}
    <txt
      tag={row}
      deletedisabled={row === "Pinned"}
      movedisabled={row === "Pinned"}
      rowbackground={row === "Pinned" ? "#FFCC0033" : undefined}
      rowseparatortint="orange">{row}</txt
    >
  {/each}
  <txt
    color="secondary"
    rowinsets={{ vertical: 16, horizontal: 32 }}
    rowseparator="hidden"
    deletedisabled
    movedisabled
  >
    Selected: {selected ?? "nothing"}
  </txt>
</list>
