<script lang="ts">
  let zoom = $state(100);
</script>

<vstack spacing={12}>
  <controlgroup title="Zoom">
    <btn onclick={() => (zoom -= 10)}>
      <sfsymbol name="minus.magnifyingglass" label="Zoom out" />
    </btn>
    <btn onclick={() => (zoom += 10)}>
      <sfsymbol name="plus.magnifyingglass" label="Zoom in" />
    </btn>
  </controlgroup>
  <txt color="secondary">{zoom}%</txt>
</vstack>
