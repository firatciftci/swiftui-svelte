<script lang="ts">
  import { withAnimation } from "swiftui-svelte";
  import { onBackground } from "swiftui-svelte/app";
  import { DisclosureGroup, Sheet, TextField } from "swiftui-svelte/components";
  import { env } from "swiftui-svelte/env";

  let count = $state(0);
  let seconds = $state(0);
  let name = $state("");
  let editingName = $state(false);
  let showSheet = $state(false);
  let celebrating = $state(false);
  let returns = $state(0);
  let stars = $state<number | null>(null);
  let fetchError = $state<string | null>(null);
  let showsLayouts = $state(false);
  let carouselOffset = $state(0);
  let carouselWidth = $state(0);

  const swatches = [
    "red",
    "orange",
    "yellow",
    "green",
    "mint",
    "teal",
    "blue",
    "indigo",
    "purple",
    "pink",
  ] as const;

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

  $effect(() => onBackground(() => returns++));

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
          <btn onclick={() => withAnimation(() => count--, "bouncy")}>
            <sfsymbol name="minus.circle.fill" label="Decrease" font="title" />
          </btn>
          <txt size={34} design="rounded" weight="heavy">{count}</txt>
          <btn onclick={() => withAnimation(() => count++, "bouncy")}>
            <sfsymbol name="plus.circle.fill" label="Increase" font="title" />
          </btn>
        </hstack>
        <progressview value={Math.min(Math.max(count, 0), 10)} total={10} />
        <txt font="caption" color="secondary">Running for {seconds}s</txt>
        {#if returns > 0}
          <txt font="caption" color="secondary">
            {returns === 1
              ? "Welcome back. You've come back once."
              : `Welcome back. You've come back ${returns} times.`}
          </txt>
        {/if}
      </vstack>

      <vstack alignment="leading" spacing={8}>
        <TextField
          placeholder="Your name"
          debounce={150}
          bind:value={() => name, (value) => (name = value.slice(0, 12))}
          bind:focused={editingName}
        />
        {#if editingName}
          <btn variant="borderless" onclick={() => (editingName = false)}>
            Done editing
          </btn>
        {/if}
        {#if name.trim() !== ""}
          <txt color="accent">Hello, {name.trim()}!</txt>
        {/if}
        {#if env.keyboardHeight > 0}
          <txt font="caption" color="secondary">
            Keyboard: {Math.round(env.keyboardHeight)} pt
          </txt>
        {/if}
      </vstack>

      <hstack spacing={12}>
        <asyncimage
          src="https://github.com/sveltejs.png"
          width={48}
          height={48}
          radius={10}
        >
          <overlay alignment="bottomTrailing">
            <sfsymbol
              name="checkmark.seal.fill"
              label="Verified"
              color="accent"
              background="white"
              radius={8}
            />
          </overlay>
        </asyncimage>
        <vstack alignment="leading" spacing={2}>
          <txt font="headline" selectable>sveltejs/svelte</txt>
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

      <DisclosureGroup title="Layouts" bind:expanded={showsLayouts}>
        <lazyvgrid columns={[{ adaptive: 44 }]} spacing={8} padding={4}>
          {#each swatches as color, index (color)}
            <zstack width={44} height={44} background={color} radius={10}>
              <txt font="caption" weight="bold" color="white">{index + 1}</txt>
            </zstack>
          {/each}
        </lazyvgrid>
        <grid alignment="leading" hspacing={24} vspacing={6}>
          <gridrow>
            <txt weight="semibold">Eager</txt>
            <txt weight="semibold">Lazy</txt>
          </gridrow>
          <divider colspan={2} />
          <gridrow>
            <txt design="monospaced">vstack</txt>
            <txt design="monospaced">lazyvstack</txt>
          </gridrow>
          <gridrow>
            <txt design="monospaced">hstack</txt>
            <txt design="monospaced">lazyhstack</txt>
          </gridrow>
        </grid>
        <hstack spacing={8} testid="shapes">
          <roundedrectangle
            cornerradius={10}
            fill={{
              linear: ["#ff3e00", "orange"],
              start: "topLeading",
              end: "bottomTrailing",
            }}
            width={40}
            height={40}
          />
          <circleshape
            fill="mint"
            stroke="teal"
            linewidth={3}
            dash={[5, 3]}
            width={40}
            height={40}
          />
          <capsule
            fill="regularMaterial"
            stroke="separator"
            width={40}
            height={24}
          />
          <unevenroundedrectangle
            topleading={20}
            bottomtrailing={20}
            fill="hsl(260 80% 60%)"
            width={40}
            height={40}
          />
          <pathshape
            d="M12 21C5 16 2 12.5 2 8.5 2 5.4 4.4 3 7.5 3c1.8 0 3.5.9 4.5 2.3C13 3.9 14.7 3 16.5 3 19.6 3 22 5.4 22 8.5 22 12.5 19 16 12 21z"
            viewbox="0 0 24 24"
            fill="rgb(255 45 85)"
            width={40}
            height={40}
          />
          <pathshape
            d="M12 12V2a10 10 0 1 1-10 10z"
            viewbox="0 0 24 24"
            fill={{ angular: ["blue", "purple", "blue"] }}
            width={40}
            height={40}
          />
        </hstack>
        <scrollview
          axes="horizontal"
          snap="view"
          indicators={false}
          onscroll={(scroll) => (carouselOffset = Math.round(scroll.x))}
          onresize={(size) => (carouselWidth = Math.round(size.width))}
        >
          <hstack spacing={12}>
            {#each swatches as color, index (color)}
              <zstack width={140} height={72} background={color} radius={12}>
                <txt weight="bold" color="white">Card {index + 1}</txt>
              </zstack>
            {/each}
          </hstack>
        </scrollview>
        <txt font="caption" color="secondary">
          Scrolled {carouselOffset} pt across a {carouselWidth} pt carousel
        </txt>
        <viewthatfits axes="horizontal">
          <txt lines={1}
            >This whole sentence shows when it fits on one line.</txt
          >
          <txt lines={1}>A shorter fallback</txt>
        </viewthatfits>
        <groupbox title="GroupBox">
          <txt>Content inside a GroupBox.</txt>
        </groupbox>
      </DisclosureGroup>
    </list>

    <Sheet detent="medium" bind:presented={showSheet}>
      <vstack spacing={16} padding>
        <sfsymbol name="sparkles" font="largeTitle" color="accent" />
        <txt font="title2" weight="semibold">Hello from a sheet</txt>
        <txt color="secondary">
          The counter is at <txt weight="bold" color="primary">{count}</txt>.
        </txt>
        <txt
          font="footnote"
          color="secondary"
          markdown="Rendered by **[Svelte](https://svelte.dev)** as native **SwiftUI**."
        />
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
