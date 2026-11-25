<script lang="ts">
  import { move, ref } from "swiftui-svelte";
  import { matchURL, onOpenURL, restorable } from "swiftui-svelte/app";
  import { Searchable } from "swiftui-svelte/components";
  import TodoDetail from "./TodoDetail.svelte";
  import { addTodo, removeTodo, todos } from "./todos.svelte";

  let draft = $state("");
  const stack = restorable(
    "todos.stack",
    [],
    (value): value is Array<number> =>
      Array.isArray(value) &&
      value.every((id) => todos.some((todo) => todo.id === id)),
  ).value;
  let confirming = $state(false);
  let editing = $state(false);
  const field = ref();
  const rows = ref();

  const remaining = $derived(todos.filter((todo) => !todo.done).length);
  const finished = $derived(todos.length - remaining);
  let query = $state("");
  let filter = $state("all");
  const needle = $derived(query.trim().toLowerCase());
  const visible = $derived(
    todos.filter(
      (todo) =>
        (filter === "all" || todo.done === (filter === "done")) &&
        todo.title.toLowerCase().includes(needle),
    ),
  );

  $effect(() =>
    onOpenURL((url) => {
      const match = matchURL("todos/:id", url);
      if (match == null) return;
      const id = Number(match.id);
      stack.length = 0;
      if (todos.some((todo) => todo.id === id)) stack.push(id);
    }),
  );

  function add() {
    const title = draft.trim();
    if (title === "") return false;
    addTodo(title);
    draft = "";
    return true;
  }
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="To-dos">
    <list
      animated
      {@attach rows}
      {editing}
      oneditingchange={(next) => (editing = next)}
    >
      <hstack>
        <textfield
          testid="new-todo"
          {@attach field}
          placeholder="New to-do"
          value={draft}
          oninput={(value) => (draft = value)}
          onsubmit={() => {
            if (add()) field.focus();
          }}
        />
        <btn
          variant="prominent"
          onclick={() => {
            if (!add()) return;
            field.blur();
            rows.scrollTo("bottom");
          }}
        >
          Add
        </btn>
      </hstack>

      <sectionview
        ondelete={(indices) => {
          const ids = indices.map((index) => visible[index]?.id);
          for (const id of ids) if (id != null) removeTodo(id);
        }}
        onmove={needle === "" && filter === "all"
          ? ({ from, to }) => move(todos, from, to)
          : undefined}
      >
        {#each visible as todo (todo.id)}
          <hstack
            spacing={12}
            rowbackground={todo.done ? "#34C7591F" : undefined}
          >
            <toggle
              checked={todo.done}
              onchange={(checked) => (todo.done = checked)}
            >
              {todo.title}
            </toggle>
            <btn onclick={() => stack.push(todo.id)}>
              <sfsymbol
                name="chevron.right"
                label="Details"
                color="secondary"
              />
            </btn>
            <swipeactions>
              <btn role="destructive" onclick={() => removeTodo(todo.id)}>
                <sfsymbol name="trash" label="Delete" />
              </btn>
            </swipeactions>
            <contextmenu>
              <btn onclick={() => (todo.done = !todo.done)}>
                {#if todo.done}
                  <labelview title="Mark as not done" symbol="circle" />
                {:else}
                  <labelview title="Mark as done" symbol="checkmark.circle" />
                {/if}
              </btn>
              <btn onclick={() => stack.push(todo.id)}>
                <labelview title="Show details" symbol="info.circle" />
              </btn>
              <divider />
              <btn role="destructive" onclick={() => removeTodo(todo.id)}>
                <labelview title="Delete" symbol="trash" />
              </btn>
              <preview>
                <vstack alignment="leading" spacing={6} padding={20}>
                  <txt font="headline">{todo.title}</txt>
                  <txt font="subheadline" color="secondary">
                    {todo.done ? "Done" : "Not done yet"}
                  </txt>
                </vstack>
              </preview>
            </contextmenu>
          </hstack>
        {/each}
      </sectionview>

      {#if visible.length === 0 && needle !== ""}
        <contentunavailableview variant="search" {query} />
      {/if}

      <txt font="footnote" color="secondary">
        {remaining === 0 ? "All done" : `${remaining} left`}
      </txt>
    </list>

    <Searchable
      bind:value={query}
      bind:selectedscope={filter}
      onpresentedchange={(presented) => {
        if (!presented) filter = "all";
      }}
      prompt="Search to-dos"
      placement="navigationBarDrawer"
      drawer="always"
      scopes={[
        { value: "all", title: "All" },
        { value: "open", title: "Open" },
        { value: "done", title: "Done" },
      ]}
    />

    <toolbar placement="leading">
      <btn onclick={() => (editing = !editing)}>
        {editing ? "Done" : "Edit"}
      </btn>
    </toolbar>

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
