<script lang="ts">
  import { Sheet, TextField } from "swiftui-svelte/components";

  let count = $state(0);
  let seconds = $state(0);
  let name = $state("");
  let showSheet = $state(false);
  let celebrating = $state(false);
  let stars = $state<number | null>(null);
  let fetchError = $state<string | null>(null);

  async function loadStars() {
    fetchError = null;
    try {
      const response = await fetch(
        "https://api.github.com/repos/sveltejs/svelte",
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const repo: unknown = await response.json();
      if (
        typeof repo === "object" &&
        repo != null &&
        "stargazers_count" in repo
      ) {
        stars = Number(repo.stargazers_count);
      }
    } catch (error) {
      fetchError = error instanceof Error ? error.message : String(error);
    }
  }

  $effect(() => {
    loadStars();
  });

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
            <sfsymbol name="minus.circle.fill" label="Decrease" font="title" />
          </btn>
          <txt font="title" weight="bold">{count}</txt>
          <btn onclick={() => count++}>
            <sfsymbol name="plus.circle.fill" label="Increase" font="title" />
          </btn>
        </hstack>
        <txt font="caption" color="secondary">Running for {seconds}s</txt>
      </vstack>

      <vstack alignment="leading" spacing={8}>
        <TextField
          placeholder="Your name"
          debounce={150}
          bind:value={() => name, (value) => (name = value.slice(0, 12))}
        />
        {#if name.trim() !== ""}
          <txt color="accent">Hello, {name.trim()}!</txt>
        {/if}
      </vstack>

      <hstack spacing={12}>
        <asyncimage
          src="https://github.com/sveltejs.png"
          width={48}
          height={48}
          radius={10}
        />
        <vstack alignment="leading" spacing={2}>
          <txt font="headline">sveltejs/svelte</txt>
          {#if fetchError != null}
            <txt font="caption" color="red" lines={2}>{fetchError}</txt>
          {:else if stars == null}
            <txt font="caption" color="secondary">Loading stars…</txt>
          {:else}
            <txt font="caption" color="secondary">
              {stars.toLocaleString()} stars on GitHub
            </txt>
          {/if}
        </vstack>
        <spacer />
        <btn variant="borderless" onclick={loadStars}>
          <sfsymbol name="arrow.clockwise" label="Refresh" />
        </btn>
      </hstack>

      <btn variant="automatic" onclick={() => (showSheet = true)}>
        Show a sheet
      </btn>
    </list>

    <Sheet detent="medium" bind:presented={showSheet}>
      <vstack spacing={16} padding>
        <sfsymbol name="sparkles" font="largeTitle" color="accent" />
        <txt font="title2" weight="semibold">Hello from a sheet</txt>
        <txt color="secondary">The counter is at {count}.</txt>
        <btn onclick={() => (celebrating = !celebrating)}>
          {celebrating ? "Calm down" : "Celebrate"}
        </btn>
        {#if celebrating}
          <sfsymbol
            name="party.popper.fill"
            label="Party popper"
            font="largeTitle"
            color="orange"
            transition="scale opacity"
            animation="bouncy"
          />
        {/if}
        <btn variant="prominent" onclick={() => (showSheet = false)}>
          Done
        </btn>
      </vstack>
    </Sheet>
  </screen>
</navstack>
