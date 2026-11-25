<script lang="ts">
  import { move } from "swiftui-svelte";
  import { List } from "swiftui-svelte/components";

  const rows = $state(["A", "B", "C", "D"]);
  let picked = $state<string | number | null>(null);
  let editing = $state(false);
  let moves = $state(0);
</script>

<List testid="rows" bind:selection={picked} bind:editing>
  <sectionview
    testid="section"
    indexlabel="R"
    ondelete={(indices) => {
      for (const index of indices.toSorted((a, b) => b - a)) {
        rows.splice(index, 1);
      }
    }}
    onmove={({ from, to }) => {
      move(rows, from, to);
      moves++;
    }}
  >
    {#each rows as row (row)}
      <txt tag={row} rowseparator="hidden">{row}</txt>
    {/each}
  </sectionview>
  <txt testid="picked"
    >{picked ?? "none"} {editing ? "editing" : "done"} {moves}</txt
  >
</List>
<list
  testid="locked"
  selection="A"
  onselectionchange={() => {}}
  editing={false}
  oneditingchange={() => {}}
/>
<list testid="plain" />
