<script lang="ts">
  import { env } from "swiftui-svelte/env";
  import { effects } from "./state.svelte.ts";

  $effect(() => {
    effects.push(env.colorScheme);
  });

  $effect(() => {
    effects.push(`insets ${env.safeAreaInsets.top}`);
  });
</script>

<vstack>
  <txt testid="scheme">{env.colorScheme}</txt>
  <txt testid="size">{env.dynamicTypeSize}</txt>
  <txt testid="insets">{env.safeAreaInsets.top},{env.safeAreaInsets.bottom}</txt
  >
  <txt testid="keyboard">{env.keyboardHeight}</txt>
  {#if env.horizontalSizeClass === "regular"}
    <txt testid="wide">wide</txt>
  {/if}
</vstack>
