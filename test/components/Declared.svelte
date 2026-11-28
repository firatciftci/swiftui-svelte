<script lang="ts">
  const { faded = false }: { faded?: boolean } = $props();
</script>

<vstack opacity={faded ? 0.5 : undefined} background={undefined} spacing={4}>
  <txt>Declared</txt>
</vstack>
