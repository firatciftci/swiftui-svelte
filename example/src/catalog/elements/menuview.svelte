<script lang="ts">
  let sort = $state<string | number>("name");
  let action = $state("none yet");
</script>

<vstack spacing={12}>
  <menuview title="Options" symbol="ellipsis.circle">
    <btn onclick={() => (action = "Duplicate")}>
      <labelview title="Duplicate" symbol="plus.square.on.square" />
    </btn>
    <picker label="Sort by" value={sort} onchange={(value) => (sort = value)}>
      <choice value="name">Name</choice>
      <choice value="date">Date</choice>
    </picker>
    <menuview title="More">
      <btn onclick={() => (action = "Archive")}>Archive</btn>
    </menuview>
    <divider />
    <btn role="destructive" onclick={() => (action = "Delete")}>
      <labelview title="Delete" symbol="trash" />
    </btn>
  </menuview>
  <txt font="caption" color="secondary">Last action: {action}</txt>
</vstack>
