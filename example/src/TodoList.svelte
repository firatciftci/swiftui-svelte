<script lang="ts">
  import { onOpenURL } from "swiftui-svelte/app";
  import TodoDetail from "./TodoDetail.svelte";
  import { addTodo, removeTodo, todos } from "./todos.svelte";

  let draft = $state("");
  const stack: Array<number> = $state([]);
  let confirming = $state(false);

  const remaining = $derived(todos.filter((todo) => !todo.done).length);
  const finished = $derived(todos.length - remaining);

  $effect(() =>
    onOpenURL((url) => {
      if (url.host !== "todos") return;
      const id = Number(url.pathname.slice(1));
      stack.length = 0;
      if (todos.some((todo) => todo.id === id)) stack.push(id);
    }),
  );

  function add() {
    const title = draft.trim();
    if (title === "") return;
    addTodo(title);
    draft = "";
  }
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="To-dos">
    <list animated>
      <hstack>
        <textfield
          testid="new-todo"
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
            <sfsymbol name="chevron.right" label="Details" color="secondary" />
          </btn>
          <swipeactions>
            <btn role="destructive" onclick={() => removeTodo(todo.id)}>
              <sfsymbol name="trash" label="Delete" />
            </btn>
          </swipeactions>
        </hstack>
      {/each}

      <txt font="footnote" color="secondary">
        {remaining === 0 ? "All done" : `${remaining} left`}
      </txt>
    </list>

    {#if finished > 0}
      <toolbar>
        <btn onclick={() => (confirming = true)}>Clear done</btn>
      </toolbar>
    {/if}

    {#if confirming}
      <alert
        title="Clear finished to-dos?"
        ondismiss={() => (confirming = false)}
      >
        <txt
          >{finished === 1 ? "1 to-do" : `${finished} to-dos`} will be removed.</txt
        >
        <btn role="cancel">Cancel</btn>
        <btn
          role="destructive"
          onclick={() => {
            for (const todo of todos.filter((todo) => todo.done)) {
              removeTodo(todo.id);
            }
          }}
        >
          Clear
        </btn>
      </alert>
    {/if}
  </screen>

  {#each stack as id, depth (depth)}
    <TodoDetail {id} onclose={() => (stack.length = depth)} />
  {/each}
</navstack>
