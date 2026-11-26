<script module lang="ts">
  export const presentation = "sheet";
</script>

<script lang="ts">
  import { useScreen } from "swiftui-svelte/kit";

  const screen = useScreen();
  screen.title = "About";
</script>

<txt testid="about">About this app</txt>
