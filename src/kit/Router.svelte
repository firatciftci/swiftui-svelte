<script lang="ts">
  import { untrack } from "svelte";
  import { root } from "virtual:swiftui-svelte/routes";
  import type { AnimationOptions } from "../elements.ts";
  import Sheet from "../components/Sheet.svelte";
  import { router, start } from "./client.svelte.ts";
  import EntryView from "./EntryView.svelte";

  const {
    hosts = [],
    transition = "push",
    animation = true,
    restore = true,
  }: {
    hosts?: Array<string>;
    transition?: "push" | "fade";
    animation?: AnimationOptions;
    restore?: boolean;
  } = $props();

  $effect.pre(() => {
    router.animation = transition === "fade" ? animation : true;
  });

  start(
    () => hosts,
    untrack(() => restore),
  );

  const RootLayout = root.layout;
  const top = $derived(router.stack.at(-1));
</script>

{#snippet sheet()}
  {#if router.sheet != null}
    <Sheet presented ondismiss={() => router.dismiss()}>
      <navstack>
        <screen
          title={router.sheet.screen.title}
          subtitle={router.sheet.screen.subtitle}
          backbuttonhidden={router.sheet.screen.backButtonHidden}
        >
          <EntryView entry={router.sheet} />
        </screen>
      </navstack>
    </Sheet>
  {/if}
{/snippet}

{#snippet pushed()}
  <navstack onpop={(depth) => router.pop(depth)}>
    {#each router.stack as entry (entry.key)}
      <screen
        title={entry.screen.title}
        subtitle={entry.screen.subtitle}
        backbuttonhidden={entry.screen.backButtonHidden}
      >
        <EntryView {entry} />
        {#if entry === top}
          {@render sheet()}
        {/if}
      </screen>
    {/each}
  </navstack>
{/snippet}

{#snippet faded()}
  <zstack maxwidth="infinity" maxheight="infinity" namespace>
    {#if top != null}
      {#key top.key}
        <vstack
          transition="opacity"
          {animation}
          maxwidth="infinity"
          maxheight="infinity"
        >
          <EntryView entry={top} />
        </vstack>
      {/key}
    {/if}
    {@render sheet()}
  </zstack>
{/snippet}

{#snippet screens()}
  {#if transition === "fade"}
    {@render faded()}
  {:else}
    {@render pushed()}
  {/if}
{/snippet}

{#if RootLayout != null}
  <RootLayout data={router.rootData} params={{}}>
    {@render screens()}
  </RootLayout>
{:else}
  {@render screens()}
{/if}
