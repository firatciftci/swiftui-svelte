<script lang="ts">
  import type { Color, DragEvent } from "swiftui-svelte/elements";
  import { env } from "swiftui-svelte/env";
  import { withAnimation } from "swiftui-svelte/renderer";
  import type { Position, ToastT, ToastType } from "./types.ts";
  import { toastStore } from "./state.svelte.ts";

  const {
    toast,
    position,
    duration,
    closeButton,
    richColors,
    stackDepth = 0,
  }: {
    toast: ToastT;
    position: Position;
    duration: number;
    closeButton: boolean;
    richColors: boolean;
    stackDepth?: number;
  } = $props();

  const TINTS: Partial<Record<ToastType, Color>> = {
    success: "green",
    error: "red",
    warning: "orange",
    info: "blue",
  };
  const ICONS: Partial<Record<ToastType, string>> = {
    success: "checkmark.circle.fill",
    error: "xmark.octagon.fill",
    warning: "exclamationmark.triangle.fill",
    info: "info.circle.fill",
  };

  const isBottom = $derived(!position.startsWith("top"));
  const tint = $derived(richColors ? TINTS[toast.type] : undefined);
  const icon = $derived(ICONS[toast.type]);
  const hasClose = $derived(closeButton && toast.dismissible !== false);
  const CustomComponent = $derived(toast.component);
  const action = $derived(toast.action);
  const cancel = $derived(toast.cancel);
  const lifetime = $derived(
    toast.duration ??
      (toast.type === "loading" ? Number.POSITIVE_INFINITY : duration),
  );
  const stackShift = $derived((isBottom ? -1 : 1) * stackDepth * 10);
  const stackScale = $derived(1 - stackDepth * 0.05);

  let offset = $state({ x: 0, y: 0 });
  let isDragging = $state(false);
  let isLeaving = $state(false);
  let axis: "horizontal" | "vertical" | null = null;

  $effect(() => {
    if (toast.dismiss || isDragging || lifetime === Number.POSITIVE_INFINITY)
      return;
    const timer = setTimeout(() => {
      toast.onAutoClose?.(toast);
      toastStore.dismiss(toast.id);
    }, lifetime);
    return () => clearTimeout(timer);
  });

  function close(): void {
    toastStore.dismiss(toast.id);
  }

  function runAction(run: { onClick: () => void }): void {
    run.onClick();
    close();
  }

  function towardEdge(value: number): number {
    return isBottom ? Math.max(value, 0) : Math.min(value, 0);
  }

  function onDrag(drag: DragEvent): void {
    if (drag.phase === "changed") {
      isDragging = true;
      axis ??=
        Math.abs(drag.translation.x) > Math.abs(drag.translation.y)
          ? "horizontal"
          : "vertical";
      offset =
        axis === "horizontal"
          ? { x: drag.translation.x, y: 0 }
          : { x: 0, y: towardEdge(drag.translation.y) };
      return;
    }

    const lockedAxis = axis;
    const distance = Math.hypot(offset.x, offset.y);
    const speed = Math.hypot(drag.velocity.x, drag.velocity.y);
    axis = null;
    isDragging = false;

    if (distance < 45 && speed <= 110) {
      withAnimation(() => (offset = { x: 0, y: 0 }), {
        type: "spring",
        duration: 300,
      });
      return;
    }

    withAnimation(
      () => {
        offset =
          lockedAxis === "horizontal"
            ? { x: Math.sign(offset.x) * 300, y: 0 }
            : { x: 0, y: isBottom ? 120 : -120 };
        isLeaving = true;
      },
      { type: "easeOut", duration: 200 },
    );
    setTimeout(close, 200);
  }
</script>

<hstack
  transition={isBottom ? "move-bottom opacity" : "move-top opacity"}
  animation={{ type: "easeInOut", duration: 250 }}
  offset={{ x: 0, y: stackShift }}
  scale={stackScale}
  scaleanchor={isBottom ? "bottom" : "top"}
  ondrag={toast.dismissible === false ? undefined : onDrag}
  dragdistance={4}
>
  <hstack {offset} opacity={isLeaving ? 0 : 1}>
    {#if CustomComponent != null}
      <CustomComponent {...toast.componentProps} closeToast={close} />
    {:else}
      <hstack
        radius={16}
        shadow={{ radius: 12, y: 4 }}
        background={tint ?? "systemBackground"}
      >
        <hstack
          spacing={10}
          padding={{
            leading: 16,
            trailing: hasClose ? 8 : 16,
            top: 12,
            bottom: 12,
          }}
          minheight={44}
          maxwidth={400}
          color={tint == null ? undefined : "white"}
          opacity={stackDepth > 0 ? 0 : 1}
          glasseffect={env.liquidGlass
            ? { tint, shape: { cornerradius: 16 } }
            : undefined}
          background={env.liquidGlass ? undefined : "regularMaterial"}
        >
          {#if toast.type === "loading"}
            <progressview></progressview>
          {:else if icon != null}
            <sfsymbol name={icon} font="title3"></sfsymbol>
          {/if}
          <vstack alignment="leading" spacing={2}>
            {#if toast.title != null}
              <txt font="subheadline" weight="semibold">{toast.title}</txt>
            {/if}
            {#if toast.description != null}
              <txt font="footnote">{toast.description}</txt>
            {/if}
          </vstack>
          <spacer minlength={0}></spacer>
          {#if action != null}
            <btn variant="borderless" onclick={() => runAction(action)}>
              {action.label}
            </btn>
          {/if}
          {#if cancel != null}
            <btn variant="borderless" onclick={() => runAction(cancel)}>
              {cancel.label}
            </btn>
          {/if}
          {#if hasClose}
            <btn variant="plain" onclick={close}>
              <sfsymbol name="xmark" font="footnote" weight="semibold"
              ></sfsymbol>
            </btn>
          {/if}
        </hstack>
      </hstack>
    {/if}
  </hstack>
</hstack>
