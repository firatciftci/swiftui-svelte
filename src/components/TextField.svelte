<script lang="ts">
  import type { SvelteHTMLElements } from "svelte/elements";

  let {
    value = $bindable(""),
    oninput,
    ...rest
  }: SvelteHTMLElements["textfield"] = $props();
</script>

<textfield
  {...rest}
  {value}
  oninput={(next) => {
    value = next;
    oninput?.(next);
  }}
></textfield>
