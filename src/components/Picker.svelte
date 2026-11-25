<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["picker"] & { children?: Snippet } = $props();
</script>

<picker
  {...rest}
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</picker>
