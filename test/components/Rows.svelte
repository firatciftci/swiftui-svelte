<script lang="ts">
  const { count }: { count: number } = $props();
  let taps = $state(0);
</script>

<list>
  {#each { length: count }, index (index)}
    <hstack>
      <txt>Row {index}</txt>
      <btn onclick={() => taps++}>Tap</btn>
    </hstack>
  {/each}
</list>
<txt>{taps}</txt>
