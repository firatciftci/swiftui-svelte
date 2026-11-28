<script lang="ts">
  let rings = $state(0);
</script>

<hstack spacing={20} font="largeTitle">
  <sfsymbol name="heart" variant="circle fill" color="pink" />
  <sfsymbol name="wifi" value={0.5} label="Wi-Fi at half strength" />
  <sfsymbol
    name="cloud.sun.rain"
    rendering="palette"
    colors={["gray", "yellow", "blue"]}
  />
  <btn onclick={() => rings++}>
    <sfsymbol name="bell" effect="bounce" trigger={rings} label="Ring" />
  </btn>
  <btn onclick={() => rings++}>
    <sfsymbol name="star" effect="scale" trigger={rings} label="Grow" />
  </btn>
</hstack>
