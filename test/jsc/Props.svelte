<script lang="ts">
  import type { Snippet } from "svelte";

  const {
    a = 1,
    b = "x",
    c = false,
    d = 0,
    e = "top",
    f = null,
    children,
  }: {
    a?: number;
    b?: string;
    c?: boolean;
    d?: number;
    e?: string;
    f?: string | null;
    children: Snippet;
  } = $props();
  // svelte-ignore state_referenced_locally
  void [a, b, c, d, e, f];
</script>

{@render children()}
