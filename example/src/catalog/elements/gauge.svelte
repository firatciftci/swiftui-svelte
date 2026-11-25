<hstack spacing={24} padding>
  <gauge value={0.7} variant="circularCapacity" current="70%">
    <txt>Battery</txt>
  </gauge>
  <gauge
    value={21}
    min={0}
    max={40}
    variant="circular"
    current="21°"
    minlabel="0"
    maxlabel="40"
  >
    <txt>Temperature</txt>
  </gauge>
  <gauge value={0.4} variant="linearCapacity" width={120}>
    <txt>Storage</txt>
  </gauge>
</hstack>
