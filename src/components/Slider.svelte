<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(0),
    oninput,
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["slider"] & { children?: Snippet } = $props();
</script>

<slider
  {...rest}
  {value}
  oninput={(next) => {
    value = next;
    oninput?.(next);
  }}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</slider>
