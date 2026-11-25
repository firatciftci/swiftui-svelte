<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    selection = $bindable(),
    onchange,
    children,
    ...rest
  }: SvelteHTMLElements["tabview"] & { children?: Snippet } = $props();
</script>

<tabview
  {...rest}
  {selection}
  onchange={(next) => {
    selection = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</tabview>
