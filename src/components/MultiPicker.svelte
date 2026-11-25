<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable([]),
    onchange,
    children,
    ...rest
  }: Omit<
    Extract<SvelteHTMLElements["picker"], { multiple: true }>,
    "multiple"
  > & { children?: Snippet } = $props();
</script>

<picker
  {...rest}
  multiple
  {value}
  onchange={(next) => {
    value = next;
    onchange?.(next);
  }}
>
  {@render children?.()}
</picker>
