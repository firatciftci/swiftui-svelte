<script lang="ts">
  import type { Snippet } from "svelte";

  const { children }: { children: Snippet } = $props();
  const pointer = { inside: false };
</script>

<zstack onhover={(event) => (pointer.inside = event.phase !== "exit")}>
  {@render children()}
</zstack>
