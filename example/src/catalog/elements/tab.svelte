<script lang="ts">
  let unread = $state(5);
</script>

<tabview>
  <tab title="Inbox" symbol="tray" badge={unread}>
    <btn variant="bordered" onclick={() => (unread = 0)}>Mark all as read</btn>
  </tab>
  <tab title="Archive" symbol="archivebox">
    <txt color="secondary">Nothing archived</txt>
  </tab>
  <tab title="Search" symbol="magnifyingglass" role="search">
    <txt color="secondary">Search your mail</txt>
  </tab>
</tabview>
