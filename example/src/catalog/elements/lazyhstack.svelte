<script lang="ts">
  const items = Array.from({ length: 50 }, (_, index) => index + 1);
</script>

<scrollview axes="horizontal" indicators={false}>
  <lazyhstack spacing={12} padding>
    {#each items as item (item)}
      <zstack width={100} height={100} background="orange.gradient" radius={16}>
        <txt font="title" weight="bold" color="white">{item}</txt>
      </zstack>
    {/each}
  </lazyhstack>
</scrollview>
