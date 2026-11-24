<script lang="ts">
  import TodoDetail from "./TodoDetail.svelte";
  import { addTodo, removeTodo, todos } from "./todos.svelte";

  let draft = $state("");
  let stack: Array<number> = $state([]);

  const remaining = $derived(todos.filter((todo) => !todo.done).length);

  function add() {
    const title = draft.trim();
    if (title === "") return;
    addTodo(title);
    draft = "";
  }
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="To-dos">
    <list>
      <hstack>
        <textfield
          placeholder="New to-do"
          value={draft}
          oninput={(value) => (draft = value)}
          onsubmit={add}
        />
        <btn variant="prominent" onclick={add}>Add</btn>
      </hstack>

      {#each todos as todo (todo.id)}
        <hstack spacing={12}>
          <toggle
            checked={todo.done}
            onchange={(checked) => (todo.done = checked)}
          >
            {todo.title}
          </toggle>
          <btn onclick={() => stack.push(todo.id)}>
            <sfsymbol name="chevron.right" color="secondary" />
          </btn>
          <swipeactions>
            <btn role="destructive" onclick={() => removeTodo(todo.id)}>
              <sfsymbol name="trash" />
            </btn>
          </swipeactions>
        </hstack>
      {/each}

      <txt font="footnote" color="secondary">
        {remaining === 0 ? "All done" : `${remaining} left`}
      </txt>
    </list>
  </screen>

  {#each stack as id, depth (depth)}
    <TodoDetail {id} onclose={() => (stack.length = depth)} />
  {/each}
</navstack>
