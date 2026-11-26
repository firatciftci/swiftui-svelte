<script lang="ts">
  import type { Component } from "svelte";
  import { libraries, modifierGroups, sections } from "./catalog/sections";
  import { m } from "./paraglide/messages.js";

  type Entry = { key: string; title: string; component: Component };

  const elements = import.meta.glob<Component>("./catalog/elements/*.svelte", {
    eager: true,
    import: "default",
  });
  const librarySources = import.meta.glob<Component>(
    "./catalog/libraries/*.svelte",
    { eager: true, import: "default" },
  );
  const modifiers = import.meta.glob<Component>(
    "./catalog/modifiers/*.svelte",
    { eager: true, import: "default" },
  );

  function entry(key: string, title: string, component?: Component): Entry {
    if (component == null)
      throw new Error(`The catalog has no ${key} example.`);
    return { key, title, component };
  }

  const groups = [
    ...sections.map((section) => ({
      title: section.title,
      fullscreen: section.fullscreen ?? false,
      entries: section.elements.map((name) =>
        entry(name, name, elements[`./catalog/elements/${name}.svelte`]),
      ),
    })),
    {
      title: "Libraries",
      fullscreen: false,
      entries: libraries.map((name) =>
        entry(name, name, librarySources[`./catalog/libraries/${name}.svelte`]),
      ),
    },
    {
      title: m.catalog_modifiers(),
      fullscreen: false,
      entries: modifierGroups.map((group) =>
        entry(
          group.name,
          group.title,
          modifiers[`./catalog/modifiers/${group.name}.svelte`],
        ),
      ),
    },
  ];

  const { initial }: { initial?: string } = $props();
  const initialEntry = groups
    .flatMap((group) => group.entries)
    .find((item) => item.key === initial);

  let stack: Array<Entry> = $state.raw(initialEntry == null ? [] : [initialEntry]);
  let cover: Entry | null = $state.raw(null);
</script>

<navstack onpop={(depth) => (stack = stack.slice(0, depth))}>
  <screen title={m.tab_catalog()}>
    <list>
      {#each groups as group (group.title)}
        <sectionview header={group.title}>
          {#each group.entries as item (item.key)}
            <btn
              testid="catalog-{item.key}"
              onclick={() => {
                if (group.fullscreen) cover = item;
                else stack = [...stack, item];
              }}
            >
              <hstack>
                <txt
                  color="primary"
                  design={item.key === item.title ? "monospaced" : "default"}
                >
                  {item.title}
                </txt>
                <spacer />
                <sfsymbol
                  name={group.fullscreen
                    ? "arrow.up.left.and.arrow.down.right"
                    : "chevron.right"}
                  font="footnote"
                  weight="semibold"
                  color="tertiaryLabel"
                />
              </hstack>
            </btn>
          {/each}
        </sectionview>
      {/each}
    </list>
  </screen>
  {#each stack as item, index (index)}
    <screen title={item.title} titledisplaymode="inline">
      <item.component />
    </screen>
  {/each}
</navstack>

{#if cover != null}
  <fullscreencover ondismiss={() => (cover = null)}>
    <vstack spacing={0}>
      <cover.component />
      <btn
        testid="catalog-close"
        variant="prominent"
        padding
        onclick={() => (cover = null)}
      >
        {m.catalog_close()}
      </btn>
    </vstack>
  </fullscreencover>
{/if}
