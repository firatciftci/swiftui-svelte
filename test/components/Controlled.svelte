<script lang="ts">
  let text = $state("");
  const locked = false;
  let free = $state(false);
</script>

<textfield
  testid="limited"
  value={text}
  oninput={(value) => (text = value.slice(0, 5))}
/>
<textfield testid="uncontrolled" oninput={() => {}} />
<toggle testid="locked" checked={locked} onchange={() => {}} />
<toggle testid="free" checked={free} onchange={(value) => (free = value)} />
