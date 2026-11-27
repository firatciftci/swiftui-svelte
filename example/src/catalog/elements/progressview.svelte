<script lang="ts">
  let uploaded = $state(3);
</script>

<vstack spacing={16} padding>
  <progressview value={uploaded} max={10}>
    <txt>{uploaded} of 10 files</txt>
  </progressview>
  <btn variant="bordered" onclick={() => (uploaded = (uploaded + 1) % 11)}>
    Upload one more
  </btn>
  <progressview>
    <txt>Loading</txt>
  </progressview>
</vstack>
