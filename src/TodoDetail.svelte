<script lang="ts">
  import { removeTodo, todos } from "./todos.svelte";

  let { id, onclose }: { id: number; onclose: () => void } = $props();

  const todo = $derived(todos.find((todo) => todo.id === id));
</script>

{#if todo}
  <screen title={todo.title}>
    <list>
      <textfield
        placeholder="Title"
        value={todo.title}
        oninput={(value) => (todo.title = value)}
      />
      <toggle checked={todo.done} onchange={(checked) => (todo.done = checked)}>
        Done
      </toggle>
      <btn
        color="red"
        onclick={() => {
          onclose();
          removeTodo(id);
        }}
      >
        Delete
      </btn>
    </list>
  </screen>
{/if}
