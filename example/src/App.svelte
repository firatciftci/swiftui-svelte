<script lang="ts">
  import Playground from "./Playground.svelte";
  import TodoList from "./TodoList.svelte";
</script>

<tabview>
  <tab title="To-dos" symbol="checklist">
    <TodoList />
  </tab>
  <tab title="Playground" symbol="sparkles">
    <Playground />
  </tab>
</tabview>
