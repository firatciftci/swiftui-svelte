<script lang="ts">
  const { on }: { on: boolean } = $props();
</script>

<vstack class={on ? "bg-white" : ""} class:p-4={on}>
  <txt>Classes</txt>
</vstack>
