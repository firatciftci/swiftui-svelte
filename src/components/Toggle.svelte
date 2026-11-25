<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    checked = $bindable(false),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["toggle"] & { children?: Snippet } = $props();
</script>

<toggle
  {...rest}
  {checked}
  onchange={(next) => {
    checked = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</toggle>
