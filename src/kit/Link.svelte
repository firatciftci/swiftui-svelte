<script lang="ts">
  import type { Snippet } from "svelte";
  import { goto } from "./navigation.ts";

  const {
    href,
    replaceState = false,
    children,
  }: { href: string; replaceState?: boolean; children: Snippet } = $props();
</script>

<btn onclick={() => void goto(href, { replaceState })}>
  {@render children()}
</btn>
