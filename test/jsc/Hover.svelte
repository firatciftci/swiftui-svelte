<script lang="ts">
  import type { Snippet } from "svelte";
  import { ref } from "swiftui-svelte";

  const { children }: { children: Snippet } = $props();
  const frame = ref();
  const pointer = { inside: false };
</script>

<zstack
  {@attach frame}
  onhover={(event) => (pointer.inside = event.phase !== "exit")}
>
  {@render children()}
</zstack>
