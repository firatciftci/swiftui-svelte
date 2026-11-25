<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    presented = $bindable(false),
    ondismiss,
    children,
    ...rest
  }: SvelteHTMLElements["confirmationdialog"] & {
    presented?: boolean;
    children?: Snippet;
  } = $props();
</script>

{#if presented}
  <confirmationdialog
    {...rest}
    ondismiss={() => {
      presented = false;
      ondismiss?.();
    }}
  >
    {@render children?.()}
  </confirmationdialog>
{/if}
