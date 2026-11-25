<script lang="ts">
  import type { ScrollGeometry, Size } from "swiftui-svelte";

  let showsScroll = $state(true);
  let watchesSize = $state(false);
  let offset = $state(0);
  let width = $state(0);

  function scrolled(scroll: ScrollGeometry) {
    offset = scroll.y;
  }

  function resized(size: Size) {
    width = size.width;
  }
</script>

{#if showsScroll}
  <scrollview testid="scroller" onscroll={scrolled}>
    <txt>Offset {offset}</txt>
  </scrollview>
{:else}
  <scrollview testid="scroller"><txt>Offset {offset}</txt></scrollview>
{/if}
{#if watchesSize}
  <vstack testid="box" onresize={resized}><txt>Width {width}</txt></vstack>
{:else}
  <vstack testid="box"><txt>Width {width}</txt></vstack>
{/if}
<btn testid="toggle-scroll" onclick={() => (showsScroll = !showsScroll)}
  >Scroll</btn
>
<btn testid="toggle-size" onclick={() => (watchesSize = !watchesSize)}>Size</btn
>
