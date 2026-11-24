<script lang="ts">
  let count = $state(0);
  let seconds = $state(0);
  let name = $state("");
  let showSheet = $state(false);

  $effect(() => {
    const interval = setInterval(() => seconds++, 1000);
    return () => clearInterval(interval);
  });
</script>

<navstack>
  <screen title="Playground">
    <list>
      <vstack alignment="leading" spacing={8}>
        <txt font="headline">Counter</txt>
        <hstack spacing={16}>
          <btn onclick={() => count--}>
            <sfsymbol name="minus.circle.fill" font="title" />
          </btn>
          <txt font="title" weight="bold">{count}</txt>
          <btn onclick={() => count++}>
            <sfsymbol name="plus.circle.fill" font="title" />
          </btn>
        </hstack>
        <txt font="caption" color="secondary">Running for {seconds}s</txt>
      </vstack>

      <vstack alignment="leading" spacing={8}>
        <textfield
          placeholder="Your name"
          value={name}
          oninput={(value) => (name = value)}
        />
        {#if name.trim() !== ""}
          <txt color="accent">Hello, {name.trim()}!</txt>
        {/if}
      </vstack>

      <btn variant="automatic" onclick={() => (showSheet = true)}>
        Show a sheet
      </btn>
    </list>

    {#if showSheet}
      <sheet detent="medium" ondismiss={() => (showSheet = false)}>
        <vstack spacing={16} padding>
          <sfsymbol name="sparkles" font="largeTitle" color="accent" />
          <txt font="title2" weight="semibold">Hello from a sheet</txt>
          <txt color="secondary">The counter is at {count}.</txt>
          <btn variant="prominent" onclick={() => (showSheet = false)}>
            Done
          </btn>
        </vstack>
      </sheet>
    {/if}
  </screen>
</navstack>
