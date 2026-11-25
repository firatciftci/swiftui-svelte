<script lang="ts">
  import { withAnimation } from "swiftui-svelte";

  const items = $state([1, 2, 3]);
  let saved = $state(false);
  let next = 4;
</script>

<vstack spacing={16} padding>
  <hstack spacing={8} animated animation="snappy">
    {#each items as item (item)}
      <txt
        width={40}
        height={40}
        color="white"
        background="blue"
        radius={8}
        transition="scale opacity">{item}</txt
      >
    {/each}
  </hstack>
  <hstack>
    <btn variant="bordered" onclick={() => items.push(next++)}>Add</btn>
    <btn variant="bordered" onclick={() => items.shift()}>Remove</btn>
  </hstack>
  <btn
    variant="prominent"
    onclick={() => withAnimation(() => (saved = !saved), "bouncy")}
  >
    Save
  </btn>
  {#if saved}
    <txt
      in="move-top"
      out="opacity"
      animation={{ type: "spring", bounce: 0.4 }}
    >
      Saved!
    </txt>
  {/if}
</vstack>
