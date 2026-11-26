<script lang="ts">
  import { root } from "virtual:swiftui-svelte/routes";
  import Sheet from "../components/Sheet.svelte";
  import EntryView from "./EntryView.svelte";
  import { router, start } from "./router.svelte.ts";

  start();

  const RootLayout = root.layout;
</script>

{#snippet screens()}
  <navstack onpop={(depth) => router.pop(depth)}>
    {#each router.stack as entry (entry.key)}
      <screen
        title={entry.screen.title}
        subtitle={entry.screen.subtitle}
        backbuttonhidden={entry.screen.backButtonHidden}
      >
        <EntryView {entry} />
        {#if entry === router.stack.at(-1) && router.sheet != null}
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
      </screen>
    {/each}
  </navstack>
{/snippet}

{#if RootLayout != null}
  <RootLayout data={router.rootData} params={{}}>
    {@render screens()}
  </RootLayout>
{:else}
  {@render screens()}
{/if}
