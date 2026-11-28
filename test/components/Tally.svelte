<script lang="ts">
  import { tally } from "./shared.svelte.ts";
</script>

<btn onclick={() => tally.count++}>Tally {tally.count}</btn>
