<script lang="ts">
  const symbols = [
    "sun.max",
    "moon",
    "cloud",
    "cloud.rain",
    "snowflake",
    "wind",
    "bolt",
    "rainbow",
    "tornado",
    "thermometer.sun",
    "umbrella",
    "drop",
  ];
</script>

<scrollview>
  <lazyvgrid columns={[{ adaptive: 80 }]} spacing={12} padding>
    {#each symbols as name (name)}
      <sfsymbol
        {name}
        font="title"
        width={80}
        height={80}
        background="secondarySystemBackground"
        radius={12}
      />
    {/each}
  </lazyvgrid>
</scrollview>
