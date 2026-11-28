<script lang="ts">
  const { initial }: { initial?: number } = $props();
  let size: number | undefined = $state();
</script>

<txt font="headline" size={initial}>Created</txt>
<vstack testid="updated" font="headline" {size} ontap={() => (size = 24)}>
  <txt>Updated</txt>
</vstack>
<txt font="body" size={18} fontname="Georgia">Georgia</txt>
