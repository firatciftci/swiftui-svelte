<script lang="ts">
  import TodoDetail from "./TodoDetail.svelte";
  import { addTodo, todos } from "./todos.svelte";

  let count = $state(0);
  let seconds = $state(0);
  let name = $state("");
  let draft = $state("");
  let stack: Array<number> = $state([]);

  const remaining = $derived(todos.filter((todo) => !todo.done).length);

  $effect(() => {
    const interval = setInterval(() => seconds++, 1000);
    return () => clearInterval(interval);
  });

  function add() {
    const title = draft.trim();
    if (title === "") return;
    addTodo(title);
    draft = "";
  }
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="Svelte + SwiftUI">
    <list>
      <vstack alignment="leading" spacing={8}>
        <txt font="headline">Counter</txt>
        <hstack spacing={16}>
          <btn onclick={() => count--}>
            <sfsymbol name="minus.circle.fill" font="title" />
          </btn>
          <txt font="title" weight="bold">{count}</txt>
          <btn onclick={() => count++}>
            <sfsymbol name="plus.circle.fill" font="title" />
          </btn>
        </hstack>
        <txt font="caption" color="secondary">Running for {seconds}s</txt>
      </vstack>

      <vstack alignment="leading" spacing={8}>
        <textfield
          placeholder="Your name"
          value={name}
          oninput={(value) => (name = value)}
        />
        {#if name.trim() !== ""}
          <txt color="accent">Hello, {name.trim()}!</txt>
        {/if}
      </vstack>

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
