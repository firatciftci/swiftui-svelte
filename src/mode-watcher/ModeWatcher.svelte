<script lang="ts">
  import type { UserPrefersMode } from "./state.svelte.ts";
  import {
    modeStorageKey as defaultStorageKey,
    userPrefersMode,
  } from "./state.svelte.ts";

  const {
    defaultMode = "system",
    modeStorageKey = defaultStorageKey,
  }: { defaultMode?: UserPrefersMode; modeStorageKey?: string } = $props();

  $effect.pre(() => {
    userPrefersMode.configure(modeStorageKey, defaultMode);
  });

  $effect(() => {
    __nativeInvoke(
      0,
      "colorScheme",
      JSON.stringify({ value: userPrefersMode.current }),
    );
  });
</script>
