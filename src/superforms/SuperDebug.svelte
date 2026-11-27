<script lang="ts">
  const {
    data,
    label = "",
    display = true,
  }: { data: unknown; label?: string; display?: boolean } = $props();

  const json = $derived(JSON.stringify(data, null, 2));
</script>

{#if display}
  <vstack alignment="leading" spacing={4}>
    {#if label !== ""}
      <txt font="caption" weight="semibold">{label}</txt>
    {/if}
    <scrollview axes="horizontal">
      <txt font="caption" design="monospaced" whitespace="pre" selectable>
        {json}
      </txt>
    </scrollview>
  </vstack>
{/if}
