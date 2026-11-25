<script lang="ts">
  import { state } from "./state.svelte.ts";

  function check(label: string): string {
    if (label === "boom") throw new Error("bad label");
    return label;
  }
</script>

<vstack>
  <svelte:boundary>
    <txt>{check(state.label)}</txt>
    {#snippet failed(error, reset)}
      <txt testid="failed"
        >{error instanceof Error ? error.message : "error"}</txt
      >
      <btn
        testid="retry"
        onclick={() => {
          state.label = "fine";
          reset();
        }}>Retry</btn
      >
    {/snippet}
  </svelte:boundary>
</vstack>
