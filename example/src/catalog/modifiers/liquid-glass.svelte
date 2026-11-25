<script lang="ts">
  let expanded = $state(false);
</script>

<zstack
  padding={32}
  background={{
    linear: ["teal", "indigo"],
    start: "topLeading",
    end: "bottomTrailing",
  }}
  radius={24}
>
  <glasseffectcontainer spacing={20}>
    <hstack spacing={20}>
      <btn onclick={() => (expanded = !expanded)}>
        <sfsymbol
          name="paintbrush.fill"
          font="title"
          width={56}
          height={56}
          glasseffect={{ interactive: true }}
          glassid="brush"
        />
      </btn>
      {#if expanded}
        <sfsymbol
          name="eraser.fill"
          font="title"
          width={56}
          height={56}
          glasseffect
          glassid="eraser"
        />
        <sfsymbol
          name="scissors"
          font="title"
          width={56}
          height={56}
          glasseffect="clear"
          glassunion="tools"
        />
        <sfsymbol
          name="ruler"
          font="title"
          width={56}
          height={56}
          glasseffect="clear"
          glassunion="tools"
        />
      {/if}
    </hstack>
  </glasseffectcontainer>
</zstack>
