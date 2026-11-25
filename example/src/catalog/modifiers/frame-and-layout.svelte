<script lang="ts">
  let hidden = $state(false);
</script>

<zstack>
  <rectangle fill="secondarySystemBackground" ignoressafearea />
  <vstack spacing={12} padding={{ horizontal: 20, vertical: 12 }}>
    <txt width={200} height={44} background="mint">200 by 44 points</txt>
    <txt
      maxwidth="infinity"
      framealignment="leading"
      padding={8}
      background="teal">Fills the width</txt
    >
    <txt
      minwidth={80}
      idealwidth={160}
      maxwidth={240}
      minheight={32}
      idealheight={44}
      maxheight={60}
      background="cyan">Flexible frame</txt
    >
    <roundedrectangle
      fill="indigo"
      aspectratio={16 / 9}
      contentmode="fit"
      maxwidth={200}
    />
    <zstack>
      <circleshape
        fill="red"
        width={60}
        height={60}
        offset={{ x: -15 }}
        zindex={1}
      />
      <circleshape fill="blue" width={60} height={60} offset={{ x: 15 }} />
    </zstack>
    <hstack>
      <toggle checked={hidden} onchange={(next) => (hidden = next)}>
        Hide the badge
      </toggle>
      <txt
        {hidden}
        color="white"
        background="red"
        padding={{ horizontal: 8, vertical: 2 }}
        clipshape="capsule">Badge</txt
      >
    </hstack>
  </vstack>
</zstack>
