<script lang="ts">
  import type { Position } from "./types.ts";
  import { toastStore } from "./state.svelte.ts";
  import ToastItem from "./ToastItem.svelte";

  const {
    id,
    theme = "system",
    position = "bottom-center",
    expand = false,
    duration = 4000,
    gap = 14,
    visibleToasts = 3,
    closeButton = false,
    richColors = false,
  }: {
    id?: string;
    theme?: "light" | "dark" | "system";
    position?: Position;
    expand?: boolean;
    duration?: number;
    gap?: number;
    visibleToasts?: number;
    closeButton?: boolean;
    richColors?: boolean;
  } = $props();

  const ALIGNMENTS: Record<
    Position,
    | "top"
    | "bottom"
    | "topLeading"
    | "topTrailing"
    | "bottomLeading"
    | "bottomTrailing"
  > = {
    "top-center": "top",
    "bottom-center": "bottom",
    "top-left": "topLeading",
    "top-right": "topTrailing",
    "bottom-left": "bottomLeading",
    "bottom-right": "bottomTrailing",
  };

  const visible = $derived(
    toastStore.toasts.filter(
      (toast) => !toast.dismiss && toast.toasterId === id,
    ),
  );
  let isExpanded = $state(false);
  const isStacked = $derived(!expand && !isExpanded && visible.length > 1);
  const flow = $derived(
    position.startsWith("top") ? visible : [...visible].reverse(),
  );
  const stack = $derived(visible.slice(0, visibleToasts).reverse());
  const alignment = $derived(ALIGNMENTS[position]);
  const scheme = $derived(theme === "system" ? undefined : theme);
</script>

{#if visible.length > 0}
  {#if isStacked}
    <zstack
      padding={{ horizontal: 8, vertical: 8 }}
      maxwidth="infinity"
      maxheight="infinity"
      framealignment={alignment}
      colorscheme={scheme}
      ontap={() => (isExpanded = true)}
    >
      {#each stack as toast (toast.id)}
        <ToastItem
          {toast}
          {position}
          {duration}
          {closeButton}
          {richColors}
          stackDepth={visible.indexOf(toast)}
        />
      {/each}
    </zstack>
  {:else}
    <vstack
      spacing={gap}
      padding={{ horizontal: 8, vertical: 8 }}
      maxwidth="infinity"
      maxheight="infinity"
      framealignment={alignment}
      colorscheme={scheme}
      ontap={() => (isExpanded = false)}
    >
      {#each flow as toast (toast.id)}
        <ToastItem {toast} {position} {duration} {closeButton} {richColors} />
      {/each}
    </vstack>
  {/if}
{/if}
