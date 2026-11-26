<script lang="ts">
  import { setContext, untrack } from "svelte";
  import type { Entry } from "./client.svelte.ts";
  import Layer from "./Layer.svelte";
  import { screenKey } from "./screen.ts";

  const { entry }: { entry: Entry } = $props();
  setContext(
    screenKey,
    untrack(() => entry.screen),
  );
</script>

<Layer chain={entry.view.chain} />
