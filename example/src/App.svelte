<script lang="ts">
  import { matchURL, onOpenURL, restorable } from "swiftui-svelte/app";
  import { TabView } from "swiftui-svelte/components";
  import { Router } from "swiftui-svelte/kit";
  import Catalog from "./Catalog.svelte";
  import { language } from "./language.svelte";
  import { m } from "./paraglide/messages.js";
  import Playground from "./Playground.svelte";
  import Settings from "./Settings.svelte";
  import { todos } from "./todos.svelte";

  const { catalog }: { catalog?: string } = $props();

  const tab = restorable("app.tab", "todos");

  $effect.pre(() => {
    if (catalog != null) tab.value = "catalog";
  });
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
    <Router />
  </tab>
  <tabsection title={m.tab_section_examples()}>
    <tab title={m.tab_catalog()} symbol="square.grid.2x2" value="catalog">
      <Catalog initial={catalog} />
    </tab>
    <tab title={m.tab_playground()} symbol="sparkles" value="playground">
      <Playground />
    </tab>
  </tabsection>
  <tab title={m.tab_settings()} symbol="gearshape" value="settings">
    <Settings />
  </tab>
</TabView>
