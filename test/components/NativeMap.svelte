<script lang="ts">
  let region = $state("none");
</script>

<weathermap
  testid="map"
  latitude={41.88}
  longitude={-87.63}
  onregionchange={(change) => (region = `${change.latitude}`)}
/>
<txt>{region}</txt>
