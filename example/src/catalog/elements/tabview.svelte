<script lang="ts">
  const pages = ["Welcome", "Sync", "Done"];
  let page = $state<string | number>("Welcome");
</script>

<tabview
  variant="page"
  indexdisplay="visible"
  selection={page}
  onchange={(value) => (page = value)}
  background="indigo"
>
  {#each pages as title (title)}
    <tab {title} value={title}>
      <txt font="largeTitle" weight="bold" color="white">{title}</txt>
    </tab>
  {/each}
</tabview>
