<script lang="ts">
  let open = $state(false);
  let cleared = $state(false);
</script>

<vstack spacing={12}>
  <btn variant="bordered" role="destructive" onclick={() => (open = true)}>
    Clear history
  </btn>
  {#if cleared}
    <txt color="secondary">History cleared</txt>
  {/if}
</vstack>
{#if open}
  <alert title="Clear your history?" ondismiss={() => (open = false)}>
    <txt>This can't be undone.</txt>
    <btn role="cancel">Cancel</btn>
    <btn role="destructive" onclick={() => (cleared = true)}>Clear</btn>
  </alert>
{/if}
