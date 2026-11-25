<script lang="ts">
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(""),
    focused = $bindable(),
    oninput,
    onfocus,
    onblur,
    ...rest
  }: SvelteHTMLElements["textfield"] & { format?: undefined } = $props();
</script>

<textfield
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
></textfield>
