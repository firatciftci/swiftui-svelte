<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    selection = $bindable([]),
    editing = $bindable(false),
    onselectionchange,
    oneditingchange,
    children,
    ...rest
  }: Omit<
    Extract<SvelteHTMLElements["list"], { multiple: true }>,
    "multiple"
  > & { children?: Snippet } = $props();
</script>

<list
  {...rest}
  multiple
  {selection}
  {editing}
  onselectionchange={(next) => {
    selection = next;
    onselectionchange?.(next);
  }}
  oneditingchange={(next) => {
    editing = next;
    oneditingchange?.(next);
  }}
>
  {@render children?.()}
</list>
