<script lang="ts">
  let volume = $state(0.5);
  let rating = $state(3);
</script>

<formview>
  <slider value={volume} oninput={(value) => (volume = value)}>
    <txt>Volume</txt>
  </slider>
  <slider
    value={rating}
    min={1}
    max={5}
    step={1}
    onchange={(value) => (rating = value)}
  >
    <txt>Rating</txt>
  </slider>
  <txt color="secondary">
    Volume {Math.round(volume * 100)}%, rating {rating}
  </txt>
</formview>
