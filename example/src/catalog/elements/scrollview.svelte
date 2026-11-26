<script lang="ts">
  import { ref } from "swiftui-svelte";

  const colors = [
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
  ] as const;
  let offset = $state(0);
  const column = ref();
  let locked = $state(false);
  let phase = $state("idle");
  let lastShown = $state(0);
</script>

<vstack spacing={12}>
  <scrollview
    axes="horizontal"
    snap="view"
    indicators={false}
    onscroll={(scroll) => (offset = Math.round(scroll.x))}
  >
    <hstack spacing={12} padding={{ horizontal: 16 }}>
      {#each colors as color (color)}
        <roundedrectangle
          fill={color}
          width={220}
          height={140}
          cornerradius={20}
        />
      {/each}
    </hstack>
  </scrollview>
  <txt font="caption" color="secondary">Scrolled {offset} points</txt>
  <hstack spacing={12}>
    <btn variant="bordered" onclick={() => column.scrollTo({ y: 0 })}>Top</btn>
    <btn
      variant="bordered"
      onclick={() => column.scrollTo({ y: 400 }, { animated: false })}
      >Offset 400</btn
    >
    <btn variant="bordered" onclick={() => (locked = !locked)}>
      {locked ? "Unlock" : "Lock"}
    </btn>
  </hstack>
  <scrollview
    {@attach column}
    height={160}
    scrolldisabled={locked}
    onscrollphase={(event) => (phase = event.phase)}
  >
    <vstack spacing={8} padding>
      {#each Array.from({ length: 20 }, (_, index) => index + 1) as row (row)}
        <txt
          padding
          background="secondarySystemBackground"
          radius={8}
          onscrollvisibility={(event) => {
            if (event.visible) lastShown = row;
          }}>Row {row}</txt
        >
      {/each}
    </vstack>
  </scrollview>
  <txt font="caption" color="secondary">
    Phase: {phase}. Last row shown: {lastShown}.
  </txt>
</vstack>
