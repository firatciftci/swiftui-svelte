<script lang="ts">
  import { beforeNavigate } from "$app/navigation";
  import { useScreen } from "swiftui-svelte/kit";

  const screen = useScreen();
  screen.title = "Guarded";

  beforeNavigate((navigation) => {
    if (navigation.to.url.pathname === "/items/1") navigation.cancel();
  });
</script>

<txt testid="guarded">Guarded</txt>
