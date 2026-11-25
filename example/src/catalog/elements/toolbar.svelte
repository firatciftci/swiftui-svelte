<script lang="ts">
  let count = $state(0);
</script>

<vstack>
  <txt font="largeTitle" weight="bold">{count}</txt>
  <toolbar>
    <btn onclick={() => count++}>
      <sfsymbol name="plus" label="Add one" />
    </btn>
  </toolbar>
  <toolbar placement="bottom">
    <btn onclick={() => (count = 0)}>Reset</btn>
  </toolbar>
</vstack>
