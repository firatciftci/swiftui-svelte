<script lang="ts">
  let count = $state(0);
  let name = $state("");
</script>

<vstack spacing={8}>
  <txt font="headline">Count: {count}</txt>
  <btn onclick={() => count++}>Increment</btn>
  <textfield value={name} oninput={(value) => (name = value)} />
  {#if name !== ""}
    <txt>Hello, {name}!</txt>
  {/if}
</vstack>
