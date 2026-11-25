<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable("#000000"),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["colorpicker"] & { children?: Snippet } = $props();
</script>

<colorpicker
  {...rest}
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</colorpicker>
