<script lang="ts">
  import type { Snippet } from "svelte";
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    visibility = $bindable(),
    compactcolumn = $bindable(),
    onvisibilitychange,
    oncompactcolumnchange,
    children,
    ...rest
  }: SvelteHTMLElements["navsplitview"] & { children?: Snippet } = $props();
</script>

<navsplitview
  {...rest}
  {visibility}
  {compactcolumn}
  onvisibilitychange={(next) => {
    visibility = next;
    onvisibilitychange?.(next);
  }}
  oncompactcolumnchange={(next) => {
    compactcolumn = next;
    oncompactcolumnchange?.(next);
  }}
>
  {@render children?.()}
</navsplitview>
