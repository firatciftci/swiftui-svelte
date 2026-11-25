<script lang="ts">
  const fruits = ["Apple", "Banana", "Cherry", "Grape", "Mango", "Peach"];
  let query = $state("");
  const matches = $derived(
    fruits.filter((fruit) =>
      fruit.toLowerCase().includes(query.trim().toLowerCase()),
    ),
  );
</script>

<list>
  {#each matches as fruit (fruit)}
    <txt>{fruit}</txt>
  {/each}
  {#if matches.length === 0}
    <contentunavailableview variant="search" {query} />
  {/if}
</list>
<searchable
  value={query}
  oninput={(value) => (query = value)}
  prompt="Fruits"
/>
