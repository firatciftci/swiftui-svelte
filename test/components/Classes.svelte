<script lang="ts">
  const { className, padding }: { className: string; padding?: number } =
    $props();
</script>

<vstack class={className} {padding}>
  <txt>Classes</txt>
</vstack>
