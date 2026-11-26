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
</vstack>
