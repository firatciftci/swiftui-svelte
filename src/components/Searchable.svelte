<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(),
    presented = $bindable(),
    tokens = $bindable(),
    selectedscope = $bindable(),
    oninput,
    onpresentedchange,
    ontokenschange,
    onscopechange,
    children,
    ...rest
  }: SvelteHTMLElements["searchable"] & { children?: Snippet } = $props();
</script>

<searchable
  {...rest}
  {value}
  {presented}
  {tokens}
  {selectedscope}
  oninput={(next) => {
    value = next;
    oninput?.(next);
  }}
  onpresentedchange={(next) => {
    presented = next;
    onpresentedchange?.(next);
  }}
  ontokenschange={(next) => {
    tokens = next;
    ontokenschange?.(next);
  }}
  onscopechange={(next) => {
    selectedscope = next;
    onscopechange?.(next);
  }}
>
  {@render children?.()}
</searchable>
