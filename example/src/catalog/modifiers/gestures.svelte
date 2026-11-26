<script lang="ts">
  let last = $state("Try a gesture");
  let drag = $state({ x: 0, y: 0 });
  let zoom = $state(1);
  let angle = $state(0);
  let hovered = $state("Move the pointer over the box");
</script>

<vstack spacing={20} padding>
  <txt font="headline">{last}</txt>
  <txt
    padding
    width={240}
    background="quaternarySystemFill"
    radius={8}
    onhover={(event) =>
      (hovered =
        event.phase === "exit"
          ? "Left the box"
          : `${event.phase} at ${Math.round(event.location?.x ?? 0)}, ${Math.round(event.location?.y ?? 0)}`)}
    >{hovered}</txt
  >
  <hstack spacing={12}>
    <txt
      padding
      background="yellow"
      radius={8}
      tapcount={2}
      ontap={() => (last = "Double tap")}>Double-tap me</txt
    >
    <txt
      padding
      background="orange"
      radius={8}
      longpressduration={1}
      onlongpress={() => (last = "Long press")}>Hold me</txt
    >
  </hstack>
  <zstack
    width={240}
    height={120}
    background="quaternarySystemFill"
    radius={16}
    dragdistance={0}
    ondrag={(event) =>
      (drag = event.phase === "ended" ? { x: 0, y: 0 } : event.translation)}
  >
    <circleshape fill="blue" width={48} height={48} offset={drag} />
  </zstack>
  <zstack
    width={240}
    height={160}
    background="quaternarySystemFill"
    radius={16}
    onmagnify={(event) =>
      (zoom = event.phase === "ended" ? 1 : event.magnification)}
    onrotate={(event) => (angle = event.phase === "ended" ? 0 : event.degrees)}
  >
    <roundedrectangle
      fill="green"
      width={80}
      height={80}
      scale={zoom}
      rotation={angle}
    />
  </zstack>
</vstack>
