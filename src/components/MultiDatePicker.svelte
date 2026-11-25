<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable([]),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["multidatepicker"] & { children?: Snippet } = $props();
</script>

<multidatepicker
  {...rest}
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</multidatepicker>
