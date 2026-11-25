<script lang="ts">
  import type { SearchToken } from "swiftui-svelte";
  import { Searchable } from "swiftui-svelte/components";

  const kinds = [
    { id: "fruit", label: "Fruit", symbol: "basket" },
    { id: "vegetable", label: "Vegetable", symbol: "carrot" },
  ];
  const produce = [
    { name: "Apple", kind: "fruit" },
    { name: "Apricot", kind: "fruit" },
    { name: "Banana", kind: "fruit" },
    { name: "Carrot", kind: "vegetable" },
    { name: "Lemon", kind: "fruit" },
    { name: "Lettuce", kind: "vegetable" },
    { name: "Pepper", kind: "vegetable" },
  ];

  let query = $state("");
  let tokens = $state<Array<SearchToken>>([]);
  let searching = $state(false);
  let submitted = $state<string | null>(null);

  const needle = $derived(query.trim().toLowerCase());
  const chosen = $derived(
    tokens.map((token) => (typeof token === "string" ? token : token.id)),
  );
  const matches = $derived(
    produce.filter(
      (item) =>
        (chosen.length === 0 || chosen.includes(item.kind)) &&
        item.name.toLowerCase().includes(needle),
    ),
  );
  const completions = $derived(
    needle === ""
      ? []
      : matches.filter(
          (item) =>
            item.name.toLowerCase().startsWith(needle) &&
            item.name.toLowerCase() !== needle,
        ),
  );
</script>

<screen title="Produce" titledisplaymode="inline">
  <list>
    <txt color="secondary">
      Type a name, or pick Fruit or Vegetable to filter by kind.
    </txt>
    <txt testid="search-state" font="caption" color="secondary">
      {searching ? "Searching" : "Not searching"} · {submitted == null
        ? "No search yet"
        : `Last search: ${submitted}`}
    </txt>
    {#each matches as item (item.name)}
      <labelview
        title={item.name}
        symbol={item.kind === "fruit" ? "basket" : "carrot"}
      />
    {/each}
    {#if matches.length === 0}
      <contentunavailableview variant="search" {query} />
    {/if}
  </list>
  <Searchable
    bind:value={query}
    bind:tokens
    bind:presented={searching}
    suggestedtokens={needle === ""
      ? kinds.filter((kind) => !chosen.includes(kind.id))
      : []}
    prompt="Fruits and vegetables"
    placement="navigationBarDrawer"
    drawer="always"
    onsubmit={() => {
      const labels = tokens.map((token) =>
        typeof token === "string" ? token : token.label,
      );
      submitted = [...labels, query.trim()].filter(Boolean).join(" ");
    }}
  >
    {#each completions as item (item.name)}
      <labelview
        title={item.name}
        symbol="magnifyingglass"
        completion={item.name}
      />
    {/each}
  </Searchable>
</screen>
