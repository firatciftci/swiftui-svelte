<script lang="ts">
  const folders = ["Inbox", "Drafts", "Sent"];
  let folder = $state<string | number | null>("Inbox");
</script>

<navsplitview>
  <screen title="Mail">
    <list selection={folder} onselectionchange={(tag) => (folder = tag)}>
      {#each folders as name (name)}
        <labelview tag={name} title={name} symbol="folder" />
      {/each}
    </list>
  </screen>
  <screen title={String(folder ?? "Mail")}>
    <txt color="secondary">No messages</txt>
  </screen>
</navsplitview>
