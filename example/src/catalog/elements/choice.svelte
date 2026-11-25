<script lang="ts">
  let layout = $state<string | number>("list");
</script>

<picker
  value={layout}
  variant="segmented"
  padding
  onchange={(value) => (layout = value)}
>
  <choice value="list" symbol="list.bullet">List</choice>
  <choice value="grid" symbol="square.grid.2x2">Grid</choice>
</picker>
