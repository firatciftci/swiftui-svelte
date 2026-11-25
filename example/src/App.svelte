<script lang="ts">
  import { onOpenURL } from "swiftui-svelte/app";
  import { TabView } from "swiftui-svelte/components";
  import Playground from "./Playground.svelte";
  import Settings from "./Settings.svelte";
  import TodoList from "./TodoList.svelte";

  let tab = $state("todos");

  $effect(() =>
    onOpenURL((url) => {
      if (url.host === "todos") tab = "todos";
    }),
  );
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
