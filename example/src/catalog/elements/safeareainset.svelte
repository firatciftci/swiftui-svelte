<script lang="ts">
  const rows = Array.from({ length: 30 }, (_, index) => index + 1);
</script>

<scrollview>
  <vstack
    alignment="leading"
    spacing={8}
    padding
    maxwidth="infinity"
    framealignment="leading"
  >
    {#each rows as row (row)}
      <txt>Row {row}</txt>
    {/each}
  </vstack>
  <safeareainset edge="bottom">
    <txt maxwidth="infinity" padding background="thinMaterial">
      Pinned below the rows
    </txt>
  </safeareainset>
</scrollview>
