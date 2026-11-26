<script lang="ts">
  import type { LayoutProps } from "./$types";

  const { children }: LayoutProps = $props();
</script>

<txt testid="static-layout">Static layout</txt>
{@render children()}
