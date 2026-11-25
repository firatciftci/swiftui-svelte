<script lang="ts">
  const cities = ["Amsterdam", "Berlin", "Chicago", "Lisbon", "Tokyo"];
  let query = $state("");
  const suggestions = $derived(
    query === ""
      ? []
      : cities.filter((city) =>
          city.toLowerCase().startsWith(query.toLowerCase()),
        ),
  );
</script>

<list>
  <txt color="secondary">Type a letter to see suggestions.</txt>
</list>
<searchable value={query} oninput={(value) => (query = value)} prompt="Cities">
  {#each suggestions as city (city)}
    <labelview title={city} symbol="building.2" completion={city} />
  {/each}
</searchable>
