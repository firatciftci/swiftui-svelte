<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(new Date()),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["datepicker"] & { children?: Snippet } = $props();
</script>

<datepicker
  {...rest}
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</datepicker>
