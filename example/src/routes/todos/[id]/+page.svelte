<script lang="ts">
  import { back } from "$app/navigation";
  import { useScreen } from "swiftui-svelte/kit";
  import type { PageProps } from "./$types";
  import { removeTodo, todos } from "../../../todos.svelte";

  const { data }: PageProps = $props();

  const screen = useScreen();
  const todo = $derived(todos.find((todo) => todo.id === data.id));

  $effect.pre(() => {
    screen.title = todo?.title ?? "";
  });
</script>

{#if todo}
  <list>
    <textfield
      placeholder="Title"
      value={todo.title}
      oninput={(value) => (todo.title = value)}
    ></textfield>
    <toggle checked={todo.done} onchange={(checked) => (todo.done = checked)}>
      Done
    </toggle>
    <btn
      variant="automatic"
      role="destructive"
      onclick={() => {
        back();
        removeTodo(data.id);
      }}
    >
      Delete
    </btn>
  </list>
{/if}
