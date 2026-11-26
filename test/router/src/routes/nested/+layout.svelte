<script lang="ts">
  import type { LayoutProps } from "./$types";

  const { children }: LayoutProps = $props();
</script>

<txt testid="nested-layout">Nested layout</txt>
{@render children()}
