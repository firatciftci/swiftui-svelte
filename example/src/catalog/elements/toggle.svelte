<script lang="ts">
  let wifi = $state(true);
  let bold = $state(false);
</script>

<formview>
  <toggle checked={wifi} onchange={(next) => (wifi = next)}>Wi-Fi</toggle>
  <toggle checked={bold} variant="button" onchange={(next) => (bold = next)}>
    <labelview title="Bold" symbol="bold" />
  </toggle>
</formview>
