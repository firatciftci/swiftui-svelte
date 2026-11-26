<script lang="ts">
  import { goto } from "$app/navigation";
  import { useScreen } from "swiftui-svelte/kit";

  const screen = useScreen();
  screen.title = "Home";
</script>

<txt testid="home">Home</txt>
<btn testid="open-item" onclick={() => void goto("/items/2")}>Open</btn>
