<script lang="ts">
  import { goto } from "$app/navigation";
  import { move, ref } from "swiftui-svelte";
  import { Searchable } from "swiftui-svelte/components";
  import { useScreen } from "swiftui-svelte/kit";
  import { addTodo, removeTodo, todos } from "../todos.svelte";

  let draft = $state("");
  let confirming = $state(false);
  let editing = $state(false);
  const field = ref();
  const rows = ref();

  const screen = useScreen();
  screen.title = "To-dos";

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

  function add() {
    const title = draft.trim();
    if (title === "") return false;
    addTodo(title);
    draft = "";
    return true;
  }
</script>

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
    ></textfield>
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
      <hstack spacing={12} rowbackground={todo.done ? "#34C7591F" : undefined}>
        <toggle
          checked={todo.done}
          onchange={(checked) => (todo.done = checked)}
        >
          {todo.title}
        </toggle>
        <btn onclick={() => void goto(`/todos/${todo.id}`)}>
          <sfsymbol name="chevron.right" label="Details" color="secondary"
          ></sfsymbol>
        </btn>
        <swipeactions>
          <btn role="destructive" onclick={() => removeTodo(todo.id)}>
            <sfsymbol name="trash" label="Delete"></sfsymbol>
          </btn>
        </swipeactions>
        <contextmenu>
          <btn onclick={() => (todo.done = !todo.done)}>
            {#if todo.done}
              <labelview title="Mark as not done" symbol="circle"></labelview>
            {:else}
              <labelview title="Mark as done" symbol="checkmark.circle"
              ></labelview>
            {/if}
          </btn>
          <btn onclick={() => void goto(`/todos/${todo.id}`)}>
            <labelview title="Show details" symbol="info.circle"></labelview>
          </btn>
          <divider></divider>
          <btn role="destructive" onclick={() => removeTodo(todo.id)}>
            <labelview title="Delete" symbol="trash"></labelview>
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
    <contentunavailableview variant="search" {query}></contentunavailableview>
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
  <alert title="Clear finished to-dos?" ondismiss={() => (confirming = false)}>
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
