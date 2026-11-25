<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    selection = $bindable(null),
    editing = $bindable(false),
    onselectionchange,
    oneditingchange,
    children,
    ...rest
  }: Omit<
    Extract<SvelteHTMLElements["list"], { multiple?: false }>,
    "multiple"
  > & { children?: Snippet } = $props();
</script>

<list
  {...rest}
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
