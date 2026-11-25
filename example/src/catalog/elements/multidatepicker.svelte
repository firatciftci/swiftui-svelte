<script lang="ts">
  let days: Array<string> = $state([]);
</script>

<formview>
  <multidatepicker value={days} onchange={(value) => (days = value)}>
    <txt>Delivery days</txt>
  </multidatepicker>
  <txt color="secondary">
    {days.length}
    {days.length === 1 ? "day" : "days"} picked
  </txt>
</formview>
