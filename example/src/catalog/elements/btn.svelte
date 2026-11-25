<script lang="ts">
  let count = $state(0);
</script>

<vstack spacing={12}>
  <txt font="largeTitle" weight="bold">{count}</txt>
  <btn variant="prominent" onclick={() => count++}>Add one</btn>
  <btn variant="bordered" bordershape="capsule" repeat onclick={() => count++}>
    Hold to keep adding
  </btn>
  <btn variant="glass" role="destructive" onclick={() => (count = 0)}>Reset</btn
  >
</vstack>
