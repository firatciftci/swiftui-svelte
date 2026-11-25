# Navigation

Svelte owns the navigation stack. The first `screen` in a `navstack` is the root, and every `screen` after it is pushed on top, so you push a screen by rendering another one, usually from an `{#each}` over a state array. When the user taps the back button or swipes back, `onpop` receives the number of pushed screens that are left, and your app trims its array to match:

```svelte
<script lang="ts">
  let stack: Array<number> = $state([]);
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="To-dos">
    <!-- a button that calls stack.push(todo.id) -->
  </screen>

  {#each stack as id, depth (depth)}
    <TodoDetail {id} onclose={() => (stack.length = depth)} />
  {/each}
</navstack>
```

Each pushed screen is a regular component, so it's mounted when it's pushed and destroyed when it's popped. Removing a screen from the array pops it with the usual animation. In the example app, the to-do list and its detail screens share state through [`todos.svelte.ts`](../example/src/todos.svelte.ts).

## Search

A `searchable` inside a `screen` adds a search field to the navigation bar. `value` is the text in the field, `oninput` receives each change, and `onsubmit` fires when the user presses Search or picks a suggestion. `prompt` is the placeholder. `placement` is `automatic`, `toolbar`, `sidebar`, or `navigationBarDrawer`. On iOS 26, the drawer stays hidden until the user scrolls down, so set `placement="navigationBarDrawer"` and `drawer="always"` to keep the field showing. `presented` is true while the user is searching, and `onpresentedchange` fires when they start or cancel a search. On iOS 26, `minimize` collapses the field into a toolbar button. Use the `Searchable` component to bind `value`, `presented`, `tokens`, and `selectedscope`.

- **Suggestions.** The children of a `searchable` show in place of the screen's content while the user is searching. Give a child a `completion`, and tapping it puts that text in the field. Render suggestions only when you have some, because any child hides the content.
- **Scopes.** `scopes` lists the buttons below the field, as strings or as `{ value, title }`, and `selectedscope` is the one that's picked. `onscopechange` receives the scope the user picks, and `scopeactivation` (`automatic`, `onTextEntry`, or `onSearchPresentation`) sets when the buttons appear. SwiftUI keeps the scope when the user cancels, so reset it in `onpresentedchange` if your list should show everything again.
- **Tokens.** `tokens` are the chips in the field, as strings or as `{ id, label, symbol }`. `suggestedtokens` lists tokens the user can add, shown as suggestions. When the user picks one or deletes one, `ontokenschange` receives the new list.

```svelte
<script lang="ts">
  import { Searchable } from "swiftui-svelte/components";

  const fruits = ["Apple", "Apricot", "Banana", "Cherry"];
  let query = $state("");
  const matches = $derived(
    fruits.filter((fruit) => fruit.toLowerCase().includes(query.toLowerCase())),
  );
</script>

<navstack>
  <screen title="Fruits">
    <list>
      {#each matches as fruit (fruit)}
        <txt>{fruit}</txt>
      {/each}
      {#if matches.length === 0}
        <contentunavailableview variant="search" {query} />
      {/if}
    </list>
    <Searchable bind:value={query} prompt="Search fruits" />
  </screen>
</navstack>
```
