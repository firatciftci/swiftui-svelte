<script lang="ts">
  const colors = [
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
  ] as const;
  let offset = $state(0);
</script>

<vstack spacing={12}>
  <scrollview
    axes="horizontal"
    snap="view"
    indicators={false}
    onscroll={(scroll) => (offset = Math.round(scroll.x))}
  >
    <hstack spacing={12} padding={{ horizontal: 16 }}>
      {#each colors as color (color)}
        <roundedrectangle
          fill={color}
          width={220}
          height={140}
          cornerradius={20}
        />
      {/each}
    </hstack>
  </scrollview>
  <txt font="caption" color="secondary">Scrolled {offset} points</txt>
</vstack>
