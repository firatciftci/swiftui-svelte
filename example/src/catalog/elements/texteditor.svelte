<script lang="ts">
  let notes = $state("");
</script>

<formview>
  <sectionview header="Notes" footer="{notes.length} characters">
    <texteditor
      value={notes}
      debounce={200}
      oninput={(value) => (notes = value)}
      height={160}
    />
  </sectionview>
</formview>
