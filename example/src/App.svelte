<script lang="ts">
  import { TabView } from "swiftui-svelte/components";
  import Playground from "./Playground.svelte";
  import Settings from "./Settings.svelte";
  import TodoList from "./TodoList.svelte";

  let tab = $state("todos");
</script>

<TabView bind:selection={tab}>
  <tab title="To-dos" symbol="checklist" value="todos">
    <TodoList />
  </tab>
  <tab title="Playground" symbol="sparkles" value="playground">
    <Playground />
  </tab>
  <tab title="Settings" symbol="gearshape" value="settings">
    <Settings />
  </tab>
</TabView>
