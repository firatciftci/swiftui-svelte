<script lang="ts">
  import { matchURL, onOpenURL, restorable } from "swiftui-svelte/app";
  import { TabView } from "swiftui-svelte/components";
  import { language } from "./language.svelte";
  import { m } from "./paraglide/messages.js";
  import Playground from "./Playground.svelte";
  import Settings from "./Settings.svelte";
  import TodoList from "./TodoList.svelte";
  import { todos } from "./todos.svelte";

  const tab = restorable("app.tab", "todos");
  const remaining = $derived(todos.filter((todo) => !todo.done).length);

  $effect(() =>
    onOpenURL((url) => {
      if (matchURL("todos/*", url) != null) tab.value = "todos";
    }),
  );
</script>

<TabView
  bind:selection={tab.value}
  variant="sidebarAdaptable"
  lang={language.locale}
  dir={language.dir}
>
  <tab title={m.tab_todos()} symbol="checklist" value="todos" badge={remaining}>
    <TodoList />
  </tab>
  <tabsection title={m.tab_section_examples()}>
    <tab title={m.tab_playground()} symbol="sparkles" value="playground">
      <Playground />
    </tab>
  </tabsection>
  <tab title={m.tab_settings()} symbol="gearshape" value="settings">
    <Settings />
  </tab>
</TabView>
