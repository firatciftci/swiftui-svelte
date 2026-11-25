<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    presented = $bindable(false),
    ondismiss,
    children,
    ...rest
  }: SvelteHTMLElements["fullscreencover"] & {
    presented?: boolean;
    children?: Snippet;
  } = $props();
</script>

{#if presented}
  <fullscreencover
    {...rest}
    ondismiss={() => {
      presented = false;
      ondismiss?.();
    }}
  >
    {@render children?.()}
  </fullscreencover>
{/if}
