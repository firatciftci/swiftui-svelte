<script lang="ts">
  import { onOpenURL } from "swiftui-svelte/app";
  import { TabView } from "swiftui-svelte/components";
  import { language } from "./language.svelte";
  import { m } from "./paraglide/messages.js";
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

<TabView bind:selection={tab} lang={language.locale} dir={language.dir}>
  <tab title={m.tab_todos()} symbol="checklist" value="todos">
    <TodoList />
  </tab>
  <tab title={m.tab_playground()} symbol="sparkles" value="playground">
    <Playground />
  </tab>
  <tab title={m.tab_settings()} symbol="gearshape" value="settings">
    <Settings />
  </tab>
</TabView>
