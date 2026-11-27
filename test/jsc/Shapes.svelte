<script lang="ts">
  import Hover from "./Hover.svelte";
  import HoverPlain from "./HoverPlain.svelte";
  import Pass from "./Pass.svelte";
  import Props from "./Props.svelte";
  import { rows } from "./rows.svelte.ts";

  const { shape }: { shape: string } = $props();
</script>

{#snippet row(label: string)}<txt>{label}</txt>{/snippet}

<lazyvstack spacing={0}>
  {#if shape === "each-empty"}
    {#each rows.items as item (item.id)}{/each}
  {:else if shape === "txt-static"}
    {#each rows.items as item (item.id)}<txt>Row</txt>{/each}
  {:else if shape === "txt"}
    {#each rows.items as item (item.id)}<txt>{item.label}</txt>{/each}
  {:else if shape === "vstack-txt"}
    {#each rows.items as item (item.id)}<vstack><txt>{item.label}</txt></vstack
      >{/each}
  {:else if shape === "attrs"}
    {#each rows.items as item (item.id)}
      <vstack
        spacing={0}
        maxwidth="infinity"
        framealignment="leading"
        padding={{ vertical: 2 }}
      >
        <txt linespacing={3} alignment="leading" lang="">{item.label}</txt>
      </vstack>
    {/each}
  {:else if shape === "class"}
    {#each rows.items as item (item.id)}
      <vstack
        class="border-t border-neutral-200 px-3 py-1.5 dark:border-neutral-600"
        ><txt>{item.label}</txt></vstack
      >
    {/each}
  {:else if shape === "snippet"}
    {#each rows.items as item (item.id)}{@render row(item.label)}{/each}
  {:else if shape === "pass"}
    {#each rows.items as item (item.id)}<Pass><txt>{item.label}</txt></Pass
      >{/each}
  {:else if shape === "props"}
    {#each rows.items as item (item.id)}<Props><txt>{item.label}</txt></Props
      >{/each}
  {:else if shape === "hover-plain"}
    {#each rows.items as item (item.id)}<HoverPlain
        ><txt>{item.label}</txt></HoverPlain
      >{/each}
  {:else if shape === "hover"}
    {#each rows.items as item (item.id)}<Hover><txt>{item.label}</txt></Hover
      >{/each}
  {:else if shape === "btn"}
    {#each rows.items as item (item.id)}
      <btn variant="plain" onclick={() => void item.id}
        ><txt>{item.label}</txt></btn
      >
    {/each}
  {/if}
</lazyvstack>
