<script lang="ts">
  import type { LayoutProps } from "./$types";

  const { children }: LayoutProps = $props();
</script>

<txt testid="root-layout">Root layout</txt>
{@render children()}
