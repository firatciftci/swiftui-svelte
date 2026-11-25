<script lang="ts">
  import type { SvelteHTMLElements } from "svelte/elements";
  import type { NumberFormat } from "swiftui-svelte";

  let {
    value = $bindable(null),
    focused = $bindable(),
    oninput,
    onfocus,
    onblur,
    ...rest
  }: SvelteHTMLElements["textfield"] & { format: NumberFormat } = $props();
</script>

<textfield
  {...rest}
  {value}
  {focused}
  oninput={(next: number | null) => {
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
