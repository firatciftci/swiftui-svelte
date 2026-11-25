<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(0),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["stepper"] & { children?: Snippet } = $props();
</script>

<stepper
  {...rest}
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</stepper>
