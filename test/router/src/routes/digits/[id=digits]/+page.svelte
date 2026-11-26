<script lang="ts">
  import type { PageProps } from "./$types";

  const { params }: PageProps = $props();
</script>

<txt testid="digits">Digits {params.id}</txt>
