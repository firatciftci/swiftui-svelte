<script lang="ts">
  const rows = Array.from({ length: 40 }, (_, index) => index + 1);
  let width = $state(0);
  let city = $state<string | number>("Paris");
  let status = $state("");
  let visible = $state(0);

  async function load(signal: AbortSignal) {
    status = "Loading…";
    await new Promise((resolve) => setTimeout(resolve, 500));
    if (!signal.aborted) status = `Loaded the weather for ${city}`;
  }
</script>

<vstack
  spacing={16}
  padding
  onresize={(size) => (width = Math.round(size.width))}
>
  <txt>This stack is {width} points wide.</txt>
  <picker value={city} variant="segmented" onchange={(value) => (city = value)}>
    <choice value="Paris">Paris</choice>
    <choice value="Tokyo">Tokyo</choice>
  </picker>
  <txt ontask={load} taskid={city}>{status}</txt>
  <scrollview height={120}>
    <lazyvstack>
      {#each rows as row (row)}
        <txt onappear={() => visible++} ondisappear={() => visible--}>
          Row {row}
        </txt>
      {/each}
    </lazyvstack>
  </scrollview>
  <txt color="secondary">{visible} rows on screen</txt>
</vstack>
