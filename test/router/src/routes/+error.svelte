<script lang="ts">
  import { page } from "$app/state";
</script>

<txt testid="root-error">{page.status} {page.error?.message}</txt>
