<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>Show the cover</btn>
{#if open}
  <fullscreencover
    dismissible={false}
    presentationbackground="clear"
    ondismiss={() => (open = false)}
  >
    <vstack spacing={16} padding>
      <txt font="title2" weight="semibold">A full-screen cover</txt>
      <btn variant="prominent" onclick={() => (open = false)}>Close</btn>
    </vstack>
  </fullscreencover>
{/if}
