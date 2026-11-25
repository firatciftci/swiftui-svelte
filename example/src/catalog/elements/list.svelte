<script lang="ts">
  import { move } from "swiftui-svelte";

  let tasks = $state(["Write", "Edit", "Publish"]);
  let editing = $state(false);
</script>

<list
  variant="insetGrouped"
  {editing}
  oneditingchange={(next) => (editing = next)}
  ondelete={(indices) =>
    (tasks = tasks.filter((_, index) => !indices.includes(index)))}
  onmove={({ from, to }) => move(tasks, from, to)}
  onrefresh={() => new Promise((resolve) => setTimeout(resolve, 1000))}
>
  {#each tasks as task (task)}
    <txt>{task}</txt>
  {/each}
</list>
<toolbar>
  <btn onclick={() => (editing = !editing)}>{editing ? "Done" : "Edit"}</btn>
</toolbar>
