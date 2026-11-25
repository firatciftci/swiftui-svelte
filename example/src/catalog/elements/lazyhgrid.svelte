<script lang="ts">
  const numbers = Array.from({ length: 60 }, (_, index) => index + 1);
</script>

<scrollview axes="horizontal">
  <lazyhgrid rows={3} spacing={12} padding height={240}>
    {#each numbers as number (number)}
      <txt width={60} height={60} background="mint" radius={8}>{number}</txt>
    {/each}
  </lazyhgrid>
</scrollview>
