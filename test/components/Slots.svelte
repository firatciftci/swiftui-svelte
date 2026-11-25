<script lang="ts">
  const { title = "Fruit" }: { title?: string } = $props();
</script>

{#snippet heading(text: string)}
  <hstack><sfsymbol name="leaf" /><txt>{text}</txt></hstack>
{/snippet}

<sectionview>
  <header>{@render heading(title)}</header>
  <txt>Apple</txt>
  <footer><txt>Seasonal</txt></footer>
</sectionview>
<picker value="a">
  <label>{@render heading("Pick one")}</label>
  <choice value="a">A</choice>
</picker>
<txt>
  Badge
  <overlay alignment="topTrailing"><sfsymbol name="circle.fill" /></overlay>
  <background><zstack /></background>
</txt>
