<script lang="ts">
  let taps = $state(0);
  let locked = $state(true);
  let darkSheet = $state(false);
  let note = $state("");
</script>

<scrollview scrolldismisseskeyboard="interactively">
  <vstack spacing={16} padding>
    <datepicker value="2026-03-14" components="date" lang="ja-JP">
      <txt>Japanese dates</txt>
    </datepicker>
    <hstack dir="rtl" spacing={8}>
      <txt>1</txt>
      <txt>2</txt>
      <txt>3</txt>
    </hstack>
    <txt dynamictypesize="xxxLarge">Extra large text</txt>
    <txt dynamictypesize={{ max: "large" }}>Never larger than Large</txt>
    <vstack
      colorscheme="dark"
      padding
      background="systemBackground"
      radius={12}
    >
      <txt>Always dark</txt>
    </vstack>
    <toggle checked={locked} onchange={(next) => (locked = next)}>Lock</toggle>
    <vstack disabled={locked}>
      <btn
        variant="bordered"
        sensoryfeedback="success"
        feedbacktrigger={taps}
        onclick={() => taps++}
      >
        Tap for a haptic ({taps})
      </btn>
    </vstack>
    <textfield
      placeholder="Scroll to hide the keyboard"
      value={note}
      oninput={(value) => (note = value)}
    />
    <btn onclick={() => (darkSheet = true)}>Show a dark sheet</btn>
  </vstack>
</scrollview>
{#if darkSheet}
  <sheet detents={["medium"]} ondismiss={() => (darkSheet = false)}>
    <txt preferredcolorscheme="dark">This sheet asks for dark mode.</txt>
  </sheet>
{/if}
