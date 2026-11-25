<script lang="ts">
  let pinned = $state(false);
</script>

<hstack spacing={8} padding background="secondarySystemBackground" radius={12}>
  <sfsymbol name={pinned ? "pin.fill" : "doc"} color="accent" />
  <txt>Quarterly report</txt>
  <contextmenu>
    <btn onclick={() => (pinned = !pinned)}>
      <labelview title={pinned ? "Unpin" : "Pin"} symbol="pin" />
    </btn>
    <divider />
    <btn role="destructive">
      <labelview title="Delete" symbol="trash" />
    </btn>
  </contextmenu>
</hstack>
