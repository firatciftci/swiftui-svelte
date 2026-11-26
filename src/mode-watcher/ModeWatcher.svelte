<script lang="ts">
  import { userPrefersMode } from "./state.svelte.ts";

  $effect(() => {
    __nativeInvoke(
      0,
      "colorScheme",
      JSON.stringify({ value: userPrefersMode.current }),
    );
  });
</script>
