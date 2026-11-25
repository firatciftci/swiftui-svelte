<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    expanded = $bindable(false),
    ontoggle,
    children,
    ...rest
  }: SvelteHTMLElements["disclosuregroup"] & { children?: Snippet } = $props();
</script>

<disclosuregroup
  {...rest}
  {expanded}
  ontoggle={(next) => {
    expanded = next;
    ontoggle?.(next);
  }}
>
  {@render children?.()}
</disclosuregroup>
