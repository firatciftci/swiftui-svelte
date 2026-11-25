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
<tabview testid="pinned" selection="first" onchange={() => {}}>
  <tab title="First" value="first" />
  <tab title="Second" value="second" />
</tabview>
<navsplitview
  testid="split"
  visibility="all"
  onvisibilitychange={() => {}}
  compactcolumn="sidebar"
  oncompactcolumnchange={() => {}}
>
  <screen title="Sidebar" />
  <screen title="Detail" />
</navsplitview>
