<script lang="ts">
  let taps = $state(0);
</script>

<vstack spacing={32} padding>
  <hstack spacing={32}>
    <roundedrectangle fill="orange" width={60} height={60} rotation={30} />
    <roundedrectangle
      fill="pink"
      width={60}
      height={60}
      rotation={-15}
      rotationanchor="bottomLeading"
    />
    <roundedrectangle
      fill="purple"
      width={60}
      height={60}
      scale={{ x: 1.2, y: 0.8 }}
      scaleanchor="bottom"
    />
  </hstack>
  <zstack width={200} height={80} background="quaternarySystemFill" radius={12}>
    <circleshape
      fill="teal"
      width={24}
      height={24}
      position={{ x: 40, y: 40 }}
    />
    <circleshape fill="teal" width={24} height={24} offset={{ x: 40 }} />
  </zstack>
  <imageview
    name="Logo"
    fit="fill"
    width={80}
    height={80}
    clipshape="circle"
    label="swiftui-svelte logo"
  />
  <hstack padding contentshape="rectangle" ontap={() => taps++}>
    <txt>Tap anywhere in this row</txt>
    <spacer />
    <txt>{taps}</txt>
  </hstack>
</vstack>
