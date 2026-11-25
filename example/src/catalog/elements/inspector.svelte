<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = !open)}>Show the inspector</btn>
{#if open}
  <inspector
    columnwidth={{ min: 240, ideal: 300 }}
    detents={["medium", "large"]}
    ondismiss={() => (open = false)}
  >
    <formview>
      <labeledcontent title="Kind" value="PNG image" />
      <labeledcontent title="Size" value="2.4 MB" />
    </formview>
  </inspector>
{/if}
