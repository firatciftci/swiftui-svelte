<script lang="ts">
  const tags = [
    "Svelte",
    "SwiftUI",
    "JavaScriptCore",
    "Layout",
    "Flow",
    "Wrapping rows",
    "Spacing",
    "Alignment",
  ];
</script>

<vstack spacing={16} alignment="leading">
  <flowstack spacing={8} linespacing={12}>
    {#each tags as tag (tag)}
      <txt
        padding={{ horizontal: 10, vertical: 6 }}
        background="blue"
        color="white"
        radius={8}
      >
        {tag}
      </txt>
    {/each}
  </flowstack>
  <flowstack spacing={8} alignment="center">
    {#each tags.slice(0, 5) as tag (tag)}
      <txt
        padding={{ horizontal: 10, vertical: 6 }}
        background="teal"
        color="white"
        radius={8}
      >
        {tag}
      </txt>
    {/each}
  </flowstack>
</vstack>
