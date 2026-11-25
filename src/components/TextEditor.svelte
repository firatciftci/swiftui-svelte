<script lang="ts">
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(""),
    focused = $bindable(),
    oninput,
    onfocus,
    onblur,
    ...rest
  }: SvelteHTMLElements["texteditor"] = $props();
</script>

<texteditor
  {...rest}
  {value}
  {focused}
  oninput={(next) => {
    value = next;
    oninput?.(next);
  }}
  onfocus={() => {
    focused = true;
    onfocus?.();
  }}
  onblur={() => {
    focused = false;
    onblur?.();
  }}
></texteditor>
