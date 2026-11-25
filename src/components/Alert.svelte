<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    presented = $bindable(false),
    ondismiss,
    children,
    ...rest
  }: SvelteHTMLElements["alert"] & {
    presented?: boolean;
    children?: Snippet;
  } = $props();
</script>

{#if presented}
  <alert
    {...rest}
    ondismiss={() => {
      presented = false;
      ondismiss?.();
    }}
  >
    {@render children?.()}
  </alert>
{/if}
