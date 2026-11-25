<script lang="ts">
  import type { DragEvent } from "swiftui-svelte";

  let taps = $state(0);
  let drag = $state<DragEvent | null>(null);
  let scale = $state(1);
</script>

<zstack
  testid="canvas"
  tapcount={2}
  ontap={() => taps++}
  onlongpress={() => (taps = 0)}
  ondrag={(event) => (drag = event)}
  onmagnify={(event) => (scale = event.magnification)}
>
  <txt>Taps {taps}</txt>
  <txt>Drag {drag?.translation.x ?? 0}</txt>
  <txt>Scale {scale}</txt>
</zstack>
