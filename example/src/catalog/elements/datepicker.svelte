<script lang="ts">
  let date = $state(new Date());
</script>

<formview>
  <datepicker
    value={date}
    components="date"
    onchange={(value) => (date = value)}
  >
    <txt>Check-in</txt>
  </datepicker>
  <datepicker
    value={date}
    components="time"
    onchange={(value) => (date = value)}
  >
    <txt>Arrival</txt>
  </datepicker>
  <datepicker
    value={date}
    components="date"
    variant="graphical"
    onchange={(value) => (date = value)}
  />
</formview>
