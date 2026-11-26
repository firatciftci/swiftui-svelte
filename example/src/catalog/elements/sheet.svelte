<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>Show the sheet</btn>
{#if open}
  <sheet
    detents={["medium", "large"]}
    dragindicator="visible"
    presentationbackground={{ glass: "regular" }}
    ondismiss={() => (open = false)}
  >
    <vstack spacing={12} padding>
      <txt font="title2" weight="semibold">A sheet</txt>
      <txt color="secondary">Drag it up, or swipe it away.</txt>
      <btn onclick={() => (open = false)}>Done</btn>
    </vstack>
  </sheet>
{/if}
