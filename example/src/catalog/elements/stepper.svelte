<script lang="ts">
  let guests = $state(2);
</script>

<formview>
  <stepper
    value={guests}
    min={1}
    max={10}
    onchange={(value) => (guests = value)}
  >
    <txt>{guests} guests</txt>
  </stepper>
</formview>
