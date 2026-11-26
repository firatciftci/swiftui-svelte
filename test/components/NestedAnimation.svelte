<script lang="ts">
  import { withAnimation } from "swiftui-svelte";
  import { state as shared } from "./state.svelte.ts";

  let isRingShown = $state(true);

  $effect(() => {
    const isShown = shared.show;
    withAnimation(() => (isRingShown = isShown), "snappy");
  });
</script>

{#if shared.show}
  <txt>shown</txt>
{:else}
  <spacer />
{/if}
<circle opacity={isRingShown ? 1 : 0} />
