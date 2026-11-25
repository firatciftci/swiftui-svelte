<script lang="ts">
  let flavor = $state<string | number>("vanilla");
  let toppings = $state<Array<string | number>>(["sprinkles"]);
</script>

<formview>
  <picker label="Flavor" value={flavor} onchange={(value) => (flavor = value)}>
    <choice value="vanilla">Vanilla</choice>
    <choice value="chocolate">Chocolate</choice>
    <choice value="strawberry">Strawberry</choice>
  </picker>
  <picker
    label="Toppings"
    multiple
    variant="inline"
    value={toppings}
    onchange={(value) => (toppings = value)}
  >
    <choice value="sprinkles">Sprinkles</choice>
    <choice value="nuts">Nuts</choice>
  </picker>
</formview>
