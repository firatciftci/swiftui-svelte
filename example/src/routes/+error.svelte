<script lang="ts">
  import { goto } from "$app/navigation";
  import { page } from "$app/state";
</script>

<vstack>
  <spacer />
  <txt font="largeTitle" weight="bold">{page.status}</txt>
  <txt color="secondary">{page.error?.message}</txt>
  <btn onclick={() => void goto("/")}>To-dos</btn>
  <spacer />
</vstack>
