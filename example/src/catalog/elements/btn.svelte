<script lang="ts">
  let count = $state(0);
</script>

<vstack spacing={12}>
  <txt font="largeTitle" weight="bold">{count}</txt>
  <btn variant="prominent" onclick={() => count++}>Add one</btn>
  <btn variant="bordered" bordershape="capsule" repeat onclick={() => count++}>
    Hold to keep adding
  </btn>
  <btn variant="glass" role="destructive" onclick={() => (count = 0)}>Reset</btn
  >
  <btn
    pressed={{
      scale: 0.95,
      opacity: 0.8,
      colormultiply: "#dddddd",
      shadow: false,
      animation: "snappy",
    }}
    hovered={{
      brightness: 0.1,
      shadow: { color: "#00000033", radius: 8, y: 4 },
      animation: {
        type: "timingCurve",
        curve: [0.42, 0, 0.58, 1],
        duration: 200,
      },
    }}
    onclick={() => count++}
  >
    <txt
      color="white"
      background="blue"
      radius={8}
      shadow={{ color: "#00000026", radius: 2, y: 1 }}
      padding={{ horizontal: 16, vertical: 8 }}
    >
      Press feedback
    </txt>
  </btn>
  <btn onclick={() => count++}>
    <zstack>
      <hstack
        spacing={8}
        padding={{ horizontal: 16, vertical: 12 }}
        background="white"
        radius={12}
        shadow={{ color: "#00000033", radius: 6, y: 3 }}
        pressed={{ shadow: false }}
        hovered={{ lighten: 0.125 }}
      >
        <txt color="black" pressed={{ color: "red" }}>Nested press</txt>
        <sfsymbol name="arrow.right" hovered={{ offset: { x: 2 } }} />
      </hstack>
      <rectangle
        background="clear"
        radius={12}
        insetshadow
        opacity={0}
        pressed={{ opacity: 1 }}
      />
    </zstack>
  </btn>
  <txt
    testid="untracked-press"
    padding
    font="caption"
    color="secondary"
    pressed={{ color: "red" }}
    >This text has pressed styles, but nothing tracks presses on it, so Debug
    builds show a warning on the left edge of the screen.</txt
  >
</vstack>
