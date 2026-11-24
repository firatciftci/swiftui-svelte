<script lang="ts">
  import { removeTodo, todos } from "./todos.svelte";

  const { id, onclose }: { id: number; onclose: () => void } = $props();

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
        variant="automatic"
        role="destructive"
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
