<script lang="ts">
  let expanded = $state(false);
  let logging = $state(false);
</script>

<formview>
  <disclosuregroup
    title="Advanced"
    {expanded}
    ontoggle={(next) => (expanded = next)}
  >
    <toggle checked={logging} onchange={(next) => (logging = next)}>
      Debug logging
    </toggle>
  </disclosuregroup>
</formview>
