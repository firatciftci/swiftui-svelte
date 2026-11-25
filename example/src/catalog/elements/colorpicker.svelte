<script lang="ts">
  let color: `#${string}` = $state("#FF9500");
</script>

<formview>
  <colorpicker
    value={color}
    supportsopacity={false}
    onchange={(value) => (color = value)}
  >
    <txt>Highlight</txt>
  </colorpicker>
  <roundedrectangle fill={color} height={44} />
</formview>
