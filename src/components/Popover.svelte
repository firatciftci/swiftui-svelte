<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    presented = $bindable(false),
    ondismiss,
    children,
    ...rest
  }: SvelteHTMLElements["popover"] & {
    presented?: boolean;
    children?: Snippet;
  } = $props();
</script>

{#if presented}
  <popover
    {...rest}
    ondismiss={() => {
      presented = false;
      ondismiss?.();
    }}
  >
    {@render children?.()}
  </popover>
{/if}
