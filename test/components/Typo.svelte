<script lang="ts">
  const { extra }: { extra: Record<string, unknown> } = $props();
</script>

<txt padding={4} {...extra}>Hello</txt>
<txtt></txtt>
