<script lang="ts">
  import { back } from "$app/navigation";
  import { useScreen } from "swiftui-svelte/kit";
  import type { PageProps } from "./$types";

  const { data }: PageProps = $props();
  const screen = useScreen();

  $effect.pre(() => {
    screen.title = `Item ${data.id}`;
  });
</script>

<txt testid="item">Item {data.id} loaded {data.runs} times</txt>
<btn testid="back" onclick={() => back()}>Back</btn>
