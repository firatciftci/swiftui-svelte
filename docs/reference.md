# Element reference

This page lists every element and modifier in swiftui-svelte, with the type of each attribute and an example. A script generates it from the TSDoc in [`src/elements.ts`](../src/elements.ts) and the examples in [`example/src/catalog`](../example/src/catalog), which the example app shows in its Catalog tab. To change the page, edit those files and run `nr docs`.

Every element also takes the [modifiers](#modifiers), unless its entry says it doesn't.

- [Navigation](#navigation): [`navstack`](#navstack), [`screen`](#screen), [`navsplitview`](#navsplitview), [`tabview`](#tabview), [`tab`](#tab), [`tabsection`](#tabsection)
- [Toolbars and search](#toolbars-and-search): [`toolbar`](#toolbar), [`toolbarspacer`](#toolbarspacer), [`searchable`](#searchable)
- [Presentations](#presentations): [`sheet`](#sheet), [`fullscreencover`](#fullscreencover), [`popover`](#popover), [`inspector`](#inspector), [`alert`](#alert), [`confirmationdialog`](#confirmationdialog), [`contextmenu`](#contextmenu), [`preview`](#preview)
- [Stacks and grids](#stacks-and-grids): [`vstack`](#vstack), [`hstack`](#hstack), [`zstack`](#zstack), [`spacer`](#spacer), [`divider`](#divider), [`grid`](#grid), [`gridrow`](#gridrow), [`viewthatfits`](#viewthatfits), [`group`](#group), [`safeareainset`](#safeareainset), [`flowstack`](#flowstack), [`reflowstack`](#reflowstack)
- [Scrolling and lazy containers](#scrolling-and-lazy-containers): [`scrollview`](#scrollview), [`lazyvstack`](#lazyvstack), [`lazyhstack`](#lazyhstack), [`lazyvgrid`](#lazyvgrid), [`lazyhgrid`](#lazyhgrid)
- [Lists and forms](#lists-and-forms): [`list`](#list), [`sectionview`](#sectionview), [`swipeactions`](#swipeactions), [`formview`](#formview), [`labeledcontent`](#labeledcontent), [`disclosuregroup`](#disclosuregroup), [`groupbox`](#groupbox), [`controlgroup`](#controlgroup)
- [Text and images](#text-and-images): [`txt`](#txt), [`sfsymbol`](#sfsymbol), [`labelview`](#labelview), [`icon`](#icon), [`imageview`](#imageview), [`asyncimage`](#asyncimage), [`placeholder`](#placeholder), [`failure`](#failure), [`contentunavailableview`](#contentunavailableview)
- [Controls](#controls): [`btn`](#btn), [`linkview`](#linkview), [`sharelink`](#sharelink), [`menuview`](#menuview), [`toggle`](#toggle), [`slider`](#slider), [`stepper`](#stepper), [`progressview`](#progressview), [`gauge`](#gauge)
- [Text input](#text-input): [`textfield`](#textfield), [`securefield`](#securefield), [`texteditor`](#texteditor)
- [Pickers](#pickers): [`picker`](#picker), [`choice`](#choice), [`datepicker`](#datepicker), [`multidatepicker`](#multidatepicker), [`colorpicker`](#colorpicker)
- [Shapes](#shapes): [`rectangle`](#rectangle), [`roundedrectangle`](#roundedrectangle), [`unevenroundedrectangle`](#unevenroundedrectangle), [`circleshape`](#circleshape), [`ellipseshape`](#ellipseshape), [`capsule`](#capsule), [`pathshape`](#pathshape)
- [Layers and Liquid Glass](#layers-and-liquid-glass): [`background`](#background), [`overlay`](#overlay), [`maskview`](#maskview), [`glasseffectcontainer`](#glasseffectcontainer)
- [Modifiers](#modifiers): [typography](#typography), [color and style](#color-and-style), [frame and layout](#frame-and-layout), [transforms and shapes](#transforms-and-shapes), [animation and transitions](#animation-and-transitions), [gestures](#gestures), [appearing, tasks, and size](#appearing-tasks-and-size), [accessibility](#accessibility), [grid cells](#grid-cells), [list rows](#list-rows), [environment and feedback](#environment-and-feedback), [liquid glass](#liquid-glass), [search suggestions](#search-suggestions), [tailwind css](#tailwind-css), [tailwind native utilities](#tailwind-native-utilities)
- [Value types](#value-types)

## Navigation

### `navstack`

A `NavigationStack`: the root of a navigation hierarchy, where each `screen` after the first is pushed on top of the stack.

| Attribute     | Type                      | Description                                                                                                             |
| ------------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `onpop`       | `(depth: number) => void` | Runs when the user pops a screen, with the number of pushed screens that are left, so you can trim your state to match. |
| `columnwidth` | `ColumnWidth`             | The width of the stack when it's a column of a `navsplitview`, in points, or `{ min, ideal, max }`.                     |

```svelte
<script lang="ts">
  const fruits = ["Apples", "Pears", "Plums"];
  const stack: Array<string> = $state([]);
</script>

<navstack onpop={(depth) => (stack.length = depth)}>
  <screen title="Fruits">
    <list>
      {#each fruits as fruit (fruit)}
        <btn onclick={() => stack.push(fruit)}>{fruit}</btn>
      {/each}
    </list>
  </screen>
  {#each stack as fruit, index (index)}
    <screen title={fruit}>
      <txt>{fruit} are in season.</txt>
    </screen>
  {/each}
</navstack>
```

### `screen`

A screen in a navigation stack, a tab, or a split view column, with options for its title and bars.

| Attribute          | Type                                 | Description                                                                                          |
| ------------------ | ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `columnwidth`      | `ColumnWidth`                        | The width of the screen when it's a column of a `navsplitview`, in points, or `{ min, ideal, max }`. |
| `title`            | `string`                             | The title in the navigation bar.                                                                     |
| `subtitle`         | `string`                             | A line under the title, shown on iOS 26 and later.                                                   |
| `titledisplaymode` | `"automatic" \| "inline" \| "large"` | How the title is displayed: `automatic`, `inline`, or `large`.                                       |
| `backbuttonhidden` | `boolean`                            | Hides the back button.                                                                               |
| `navbarvisibility` | `BarVisibility`                      | Shows, hides, or automates the navigation bar: `visible`, `hidden`, or `automatic`.                  |
| `tabbarvisibility` | `BarVisibility`                      | Shows, hides, or automates the tab bar: `visible`, `hidden`, or `automatic`.                         |
| `navbarbackground` | `ShapeStyle`                         | Fills the navigation bar with a color or a material.                                                 |

```svelte
<navstack>
  <screen
    title="Library"
    subtitle="Three books"
    titledisplaymode="inline"
    navbarbackground="regularMaterial"
  >
    <list>
      <txt>The Iliad</txt>
      <txt>The Odyssey</txt>
      <txt>The Aeneid</txt>
    </list>
  </screen>
</navstack>
```

### `navsplitview`

A `NavigationSplitView`: a sidebar, content, and detail layout that collapses into a stack on iPhone.

| Attribute               | Type                                             | Description                                                                                                  |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `visibility`            | `SplitVisibility`                                | The visibility of the columns: `automatic`, `all`, `doubleColumn`, or `detailOnly`.                          |
| `onvisibilitychange`    | `(visibility: SplitVisibility) => void`          | Runs when SwiftUI or the user changes the column visibility, with the new value.                             |
| `compactcolumn`         | `SplitColumn`                                    | The column that shows on iPhone, where the columns collapse into a stack: `sidebar`, `content`, or `detail`. |
| `oncompactcolumnchange` | `(column: SplitColumn) => void`                  | Runs when the user goes back to another column on iPhone, with the column they went back to.                 |
| `variant`               | `"automatic" \| "balanced" \| "prominentDetail"` | The split view style: `automatic`, `balanced`, or `prominentDetail`.                                         |

```svelte
<script lang="ts">
  const folders = ["Inbox", "Drafts", "Sent"];
  let folder = $state<string | number | null>("Inbox");
</script>

<navsplitview>
  <screen title="Mail">
    <list selection={folder} onselectionchange={(tag) => (folder = tag)}>
      {#each folders as name (name)}
        <labelview tag={name} title={name} symbol="folder" />
      {/each}
    </list>
  </screen>
  <screen title={String(folder ?? "Mail")}>
    <txt color="secondary">No messages</txt>
  </screen>
</navsplitview>
```

### `tabview`

A `TabView` that shows the `tab` whose `value` matches `selection`.

| Attribute      | Type                                                          | Description                                                                                                             |
| -------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `selection`    | `string \| number`                                            | The `value` of the selected tab. Without it, the first tab is selected.                                                 |
| `onchange`     | `(selection: string \| number) => void`                       | Runs when the user switches tabs, with the `value` of the new tab.                                                      |
| `variant`      | `"automatic" \| "page" \| "sidebarAdaptable" \| "tabBarOnly"` | The tab view style: `automatic`, `page`, `sidebarAdaptable`, or `tabBarOnly`.                                           |
| `indexdisplay` | `"automatic" \| "always" \| "never"`                          | Shows page dots below the tabs when `variant` is `page`: `automatic`, `always`, or `never`.                             |
| `minimize`     | `"automatic" \| "never" \| "onScrollDown" \| "onScrollUp"`    | On iOS 26 and later, shrinks the tab bar while the user scrolls: `automatic`, `never`, `onScrollDown`, or `onScrollUp`. |

```svelte
<script lang="ts">
  const pages = ["Welcome", "Sync", "Done"];
  let page = $state<string | number>("Welcome");
</script>

<tabview
  variant="page"
  indexdisplay="always"
  selection={page}
  onchange={(value) => (page = value)}
  background="indigo"
>
  {#each pages as title (title)}
    <tab {title} value={title}>
      <txt font="largeTitle" weight="bold" color="white">{title}</txt>
    </tab>
  {/each}
</tabview>
```

### `tab`

A `Tab` that appears in the nearest `tabview`.

| Attribute | Type               | Description                                                                                                         |
| --------- | ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `title`   | `string`           | The title of the tab.                                                                                               |
| `symbol`  | `string`           | The SF Symbol name for the tab's icon.                                                                              |
| `value`   | `string \| number` | The value that `selection` and `onchange` use for this tab. Without it, the tab's position, starting at 0, is used. |
| `badge`   | `string \| number` | A number or a short label shown on the tab. `0` or an empty string hides it.                                        |
| `role`    | `"search"`         | `search` makes this the search tab, which iOS 26 sets apart at the end of the tab bar.                              |

```svelte
<script lang="ts">
  let unread = $state(5);
</script>

<tabview>
  <tab title="Inbox" symbol="tray" badge={unread}>
    <btn variant="bordered" onclick={() => (unread = 0)}>Mark all as read</btn>
  </tab>
  <tab title="Archive" symbol="archivebox">
    <txt color="secondary">Nothing archived</txt>
  </tab>
  <tab title="Search" symbol="magnifyingglass" role="search">
    <txt color="secondary">Search your mail</txt>
  </tab>
</tabview>
```

### `tabsection`

A `TabSection` that groups `tab` children under a heading.

| Attribute | Type     | Description                                                                             |
| --------- | -------- | --------------------------------------------------------------------------------------- |
| `title`   | `string` | The title of the section. On iPad with `sidebarAdaptable`, it's a group in the sidebar. |

This element doesn't take modifiers.

```svelte
<tabview variant="sidebarAdaptable">
  <tab title="Home" symbol="house">
    <txt>Home</txt>
  </tab>
  <tabsection title="Collections">
    <tab title="Favorites" symbol="star">
      <txt>Favorites</txt>
    </tab>
    <tab title="Recent" symbol="clock">
      <txt>Recent</txt>
    </tab>
  </tabsection>
</tabview>
```

## Toolbars and search

### `toolbar`

A `.toolbar` whose children become toolbar items of the element it sits in, such as a screen, a dialog, or a section of a page. Put it next to a `textfield` with `placement="keyboard"` to show a bar above the keyboard while the field has focus.

| Attribute   | Type               | Description                                                                                                                                          |
| ----------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `placement` | `ToolbarPlacement` | Where the toolbar items go: `trailing` (the default), `leading`, `principal`, `bottom`, `keyboard`, or a semantic placement such as `primaryAction`. |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let count = $state(0);
</script>

<vstack>
  <txt font="largeTitle" weight="bold">{count}</txt>
  <toolbar>
    <btn onclick={() => count++}>
      <sfsymbol name="plus" label="Add one" />
    </btn>
  </toolbar>
  <toolbar placement="bottom">
    <btn onclick={() => (count = 0)}>Reset</btn>
  </toolbar>
  <textfield
    placeholder="Toolbar above the keyboard"
    value=""
    oninput={() => {}}
  />
  <toolbar placement="keyboard">
    <spacer />
    <btn>Done</btn>
  </toolbar>
</vstack>
```

### `toolbarspacer`

A `ToolbarSpacer` that separates toolbar items on iOS 26 and later.

| Attribute   | Type                    | Description                                                                                                  |
| ----------- | ----------------------- | ------------------------------------------------------------------------------------------------------------ |
| `placement` | `ToolbarPlacement`      | The placement of the toolbar that the spacer sits in. Use the same placement as the toolbar items around it. |
| `variant`   | `"flexible" \| "fixed"` | `flexible` pushes the items apart, and `fixed` leaves a fixed gap between them.                              |

This element doesn't take modifiers.

```svelte
<vstack>
  <txt color="secondary">The bottom toolbar has two groups.</txt>
  <toolbar placement="bottom">
    <btn><sfsymbol name="square.and.arrow.up" label="Share" /></btn>
  </toolbar>
  <toolbarspacer placement="bottom" />
  <toolbar placement="bottom">
    <btn><sfsymbol name="heart" label="Like" /></btn>
    <btn><sfsymbol name="bookmark" label="Save" /></btn>
  </toolbar>
</vstack>
```

### `searchable`

A `.searchable` search field, added to the navigation bar of the nearest screen.

| Attribute           | Type                                                             | Description                                                                                                                                         |
| ------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `value`             | `string`                                                         | The text in the search field.                                                                                                                       |
| `oninput`           | `(value: string) => void`                                        | Runs with the new text on each change.                                                                                                              |
| `onsubmit`          | `() => void`                                                     | Runs when the user presses Search or picks a suggestion.                                                                                            |
| `prompt`            | `string`                                                         | The placeholder text of the search field.                                                                                                           |
| `placement`         | `"automatic" \| "toolbar" \| "sidebar" \| "navigationBarDrawer"` | Where the search field appears: `automatic`, `toolbar`, `sidebar`, or `navigationBarDrawer`.                                                        |
| `drawer`            | `"automatic" \| "always"`                                        | In the `navigationBarDrawer` placement, `always` keeps the field showing on iOS 26 and later. `automatic` lets it hide until the user scrolls down. |
| `presented`         | `boolean`                                                        | Whether the user is searching, such as after tapping the field. Use `bind:presented` with the `Searchable` component to bind it.                    |
| `onpresentedchange` | `(presented: boolean) => void`                                   | Runs when the user starts or cancels a search, with the new `presented` value.                                                                      |
| `tokens`            | `Array<SearchToken>`                                             | The tokens in the search field.                                                                                                                     |
| `ontokenschange`    | `(tokens: Array<SearchToken>) => void`                           | Runs when the user adds or removes a token, with the new list of tokens.                                                                            |
| `suggestedtokens`   | `Array<SearchToken>`                                             | Tokens the user can add, shown as suggestions.                                                                                                      |
| `scopes`            | `Array<SearchScope>`                                             | The scope buttons shown below the search field.                                                                                                     |
| `selectedscope`     | `string`                                                         | The `value` of the selected scope.                                                                                                                  |
| `onscopechange`     | `(scope: string) => void`                                        | Runs when the user picks a scope, with the scope's value.                                                                                           |
| `scopeactivation`   | `"automatic" \| "onTextEntry" \| "onSearchPresentation"`         | When the scope buttons appear: `automatic`, `onTextEntry`, or `onSearchPresentation`.                                                               |
| `minimize`          | `boolean`                                                        | On iOS 26 and later, collapses the search field into a toolbar button.                                                                              |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  const fruits = ["Apple", "Banana", "Cherry", "Grape", "Mango", "Peach"];
  let query = $state("");
  const matches = $derived(
    fruits.filter((fruit) =>
      fruit.toLowerCase().includes(query.trim().toLowerCase()),
    ),
  );
</script>

<list>
  {#each matches as fruit (fruit)}
    <txt>{fruit}</txt>
  {/each}
  {#if matches.length === 0}
    <contentunavailableview variant="search" {query} />
  {/if}
</list>
<searchable
  value={query}
  oninput={(value) => (query = value)}
  prompt="Fruits"
/>
```

## Presentations

### `sheet`

A `.sheet` presented from the nearest screen, tab, or presentation for as long as it's rendered.

| Attribute                | Type                                                          | Description                                                                                                                                                                                     |
| ------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `detents`                | `Array<Detent>`                                               | The heights the user can drag the presentation to: `medium`, `large`, a fraction of the screen such as `0.25`, or a height in points such as `300`. Defaults to `large`.                        |
| `dragindicator`          | `"automatic" \| "visible" \| "hidden"`                        | Shows the drag handle at the top: `visible`, `hidden`, or `automatic`.                                                                                                                          |
| `dismissible`            | `boolean`                                                     | Whether the user can dismiss the presentation by swiping it away. Set it to `false` to keep it open.                                                                                            |
| `backgroundinteraction`  | `boolean \| "automatic" \| "enabled" \| "disabled" \| Detent` | Whether the user can use the content behind the presentation: `true`, `false`, or a detent such as `0.25` to allow it only up to that height.                                                   |
| `cornerradius`           | `number`                                                      | The corner radius of the presentation in points.                                                                                                                                                |
| `presentationbackground` | `ShapeStyle \| "clear" \| { glass?: "regular" \| "clear"; }`  | The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background (`regular` or `clear` on iOS 26, and a material before that). |
| `ondismiss`              | `() => void`                                                  | Runs when the user dismisses the presentation, so you can update your state.                                                                                                                    |
| `detent`                 | `"medium" \| "large"`                                         | A single height: `medium` allows the medium and large heights, and `large` allows only the large height. Use `detents` to set several.                                                          |

```svelte
<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>Show the sheet</btn>
{#if open}
  <sheet
    detents={["medium", "large"]}
    dragindicator="visible"
    presentationbackground={{ glass: "regular" }}
    ondismiss={() => (open = false)}
  >
    <vstack spacing={12} padding>
      <txt font="title2" weight="semibold">A sheet</txt>
      <txt color="secondary">Drag it up, or swipe it away.</txt>
      <btn onclick={() => (open = false)}>Done</btn>
    </vstack>
  </sheet>
{/if}
```

### `fullscreencover`

A `.fullScreenCover` presented for as long as it's rendered.

| Attribute                | Type                                            | Description                                                                                                                        |
| ------------------------ | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `presentationbackground` | `PresentationOptions["presentationbackground"]` | The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background. |
| `dismissible`            | `boolean`                                       | Whether the user can dismiss the cover.                                                                                            |
| `ondismiss`              | `() => void`                                    | Runs when the cover is dismissed, so you can update your state.                                                                    |

```svelte
<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>Show the cover</btn>
{#if open}
  <fullscreencover
    dismissible={false}
    presentationbackground="clear"
    ondismiss={() => (open = false)}
  >
    <vstack spacing={16} padding>
      <txt font="title2" weight="semibold">A full-screen cover</txt>
      <btn variant="prominent" onclick={() => (open = false)}>Close</btn>
    </vstack>
  </fullscreencover>
{/if}
```

### `popover`

A `.popover` anchored to the element it's inside, such as a `btn`.

| Attribute                | Type                                                                 | Description                                                                                                                                                                                     |
| ------------------------ | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `detents`                | `Array<Detent>`                                                      | The heights the user can drag the presentation to: `medium`, `large`, a fraction of the screen such as `0.25`, or a height in points such as `300`. Defaults to `large`.                        |
| `dragindicator`          | `"automatic" \| "visible" \| "hidden"`                               | Shows the drag handle at the top: `visible`, `hidden`, or `automatic`.                                                                                                                          |
| `dismissible`            | `boolean`                                                            | Whether the user can dismiss the presentation by swiping it away. Set it to `false` to keep it open.                                                                                            |
| `backgroundinteraction`  | `boolean \| "automatic" \| "enabled" \| "disabled" \| Detent`        | Whether the user can use the content behind the presentation: `true`, `false`, or a detent such as `0.25` to allow it only up to that height.                                                   |
| `cornerradius`           | `number`                                                             | The corner radius of the presentation in points.                                                                                                                                                |
| `presentationbackground` | `ShapeStyle \| "clear" \| { glass?: "regular" \| "clear"; }`         | The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background (`regular` or `clear` on iOS 26, and a material before that). |
| `ondismiss`              | `() => void`                                                         | Runs when the user dismisses the presentation, so you can update your state.                                                                                                                    |
| `arrowedge`              | `Edge`                                                               | The edge of the anchor that the arrow points from: `top`, `bottom`, `leading`, or `trailing`.                                                                                                   |
| `adaptation`             | `"automatic" \| "none" \| "popover" \| "sheet" \| "fullScreenCover"` | How the popover adapts on iPhone, where it opens as a sheet by default: `automatic`, `none`, `popover`, `sheet`, or `fullScreenCover`.                                                          |

```svelte
<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>
  What's new?
  {#if open}
    <popover
      adaptation="popover"
      arrowedge="top"
      ondismiss={() => (open = false)}
    >
      <txt padding width={240}
        >Popovers point at the button that opens them.</txt
      >
    </popover>
  {/if}
</btn>
```

### `inspector`

An `.inspector` shown as a column beside the content on iPad and as a sheet on iPhone, for as long as it's rendered.

| Attribute                | Type                                                          | Description                                                                                                                                                                                     |
| ------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `detents`                | `Array<Detent>`                                               | The heights the user can drag the presentation to: `medium`, `large`, a fraction of the screen such as `0.25`, or a height in points such as `300`. Defaults to `large`.                        |
| `dragindicator`          | `"automatic" \| "visible" \| "hidden"`                        | Shows the drag handle at the top: `visible`, `hidden`, or `automatic`.                                                                                                                          |
| `dismissible`            | `boolean`                                                     | Whether the user can dismiss the presentation by swiping it away. Set it to `false` to keep it open.                                                                                            |
| `backgroundinteraction`  | `boolean \| "automatic" \| "enabled" \| "disabled" \| Detent` | Whether the user can use the content behind the presentation: `true`, `false`, or a detent such as `0.25` to allow it only up to that height.                                                   |
| `cornerradius`           | `number`                                                      | The corner radius of the presentation in points.                                                                                                                                                |
| `presentationbackground` | `ShapeStyle \| "clear" \| { glass?: "regular" \| "clear"; }`  | The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background (`regular` or `clear` on iOS 26, and a material before that). |
| `ondismiss`              | `() => void`                                                  | Runs when the user dismisses the presentation, so you can update your state.                                                                                                                    |
| `columnwidth`            | `ColumnWidth`                                                 | The width of the inspector column on iPad, in points, or `{ min, ideal, max }`.                                                                                                                 |

```svelte
<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = !open)}>Show the inspector</btn>
{#if open}
  <inspector
    columnwidth={{ min: 240, ideal: 300 }}
    detents={["medium", "large"]}
    ondismiss={() => (open = false)}
  >
    <formview>
      <labeledcontent title="Kind" value="PNG image" />
      <labeledcontent title="Size" value="2.4 MB" />
    </formview>
  </inspector>
{/if}
```

### `alert`

An `.alert` presented for as long as it's rendered, with `txt` children as its message and `btn` children as its actions.

| Attribute   | Type         | Description                                                     |
| ----------- | ------------ | --------------------------------------------------------------- |
| `title`     | `string`     | The title of the alert.                                         |
| `ondismiss` | `() => void` | Runs when the alert is dismissed, so you can update your state. |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let open = $state(false);
  let cleared = $state(false);
</script>

<vstack spacing={12}>
  <btn variant="bordered" role="destructive" onclick={() => (open = true)}>
    Clear history
  </btn>
  {#if cleared}
    <txt color="secondary">History cleared</txt>
  {/if}
</vstack>
{#if open}
  <alert title="Clear your history?" ondismiss={() => (open = false)}>
    <txt>This can't be undone.</txt>
    <btn role="cancel">Cancel</btn>
    <btn role="destructive" onclick={() => (cleared = true)}>Clear</btn>
  </alert>
{/if}
```

### `confirmationdialog`

A `.confirmationDialog` anchored to the element it's inside, with `btn` children as its actions.

| Attribute         | Type                                   | Description                                                      |
| ----------------- | -------------------------------------- | ---------------------------------------------------------------- |
| `title`           | `string`                               | The title of the dialog.                                         |
| `titlevisibility` | `"automatic" \| "visible" \| "hidden"` | Shows or hides the title: `automatic`, `visible`, or `hidden`.   |
| `ondismiss`       | `() => void`                           | Runs when the dialog is dismissed, so you can update your state. |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let open = $state(false);
  let source = $state("nothing yet");
</script>

<vstack spacing={12}>
  <btn variant="bordered" onclick={() => (open = true)}>
    Change the photo
    {#if open}
      <confirmationdialog
        title="Change the photo"
        titlevisibility="visible"
        ondismiss={() => (open = false)}
      >
        <btn onclick={() => (source = "the camera")}>Take a photo</btn>
        <btn onclick={() => (source = "the library")}
          >Choose from the library</btn
        >
        <btn role="cancel">Cancel</btn>
      </confirmationdialog>
    {/if}
  </btn>
  <txt color="secondary">Picked {source}</txt>
</vstack>
```

### `contextmenu`

A `.contextMenu` that opens its children as a menu when the user touches and holds the element, or right-clicks it on Mac.

This element has no attributes of its own.

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let pinned = $state(false);
</script>

<hstack spacing={8} padding background="secondarySystemBackground" radius={12}>
  <sfsymbol name={pinned ? "pin.fill" : "doc"} color="accent" />
  <txt>Quarterly report</txt>
  <contextmenu>
    <btn onclick={() => (pinned = !pinned)}>
      <labelview title={pinned ? "Unpin" : "Pin"} symbol="pin" />
    </btn>
    <divider />
    <btn role="destructive">
      <labelview title="Delete" symbol="trash" />
    </btn>
  </contextmenu>
</hstack>
```

### `preview`

The `.contextMenu` preview: a custom view shown above the menu in place of the element.

This element has no attributes of its own.

This element doesn't take modifiers.

```svelte
<vstack padding background="secondarySystemBackground" radius={12}>
  <txt>Touch and hold for a preview</txt>
  <contextmenu>
    <btn>
      <labelview title="Open" symbol="arrow.up.forward.app" />
    </btn>
    <preview>
      <vstack spacing={8} padding={24} width={260}>
        <sfsymbol name="photo" font="largeTitle" color="accent" />
        <txt font="headline">Beach.jpg</txt>
      </vstack>
    </preview>
  </contextmenu>
</vstack>
```

## Stacks and grids

### `vstack`

A `VStack`: lays out its children in a vertical column.

| Attribute   | Type                  | Description                                                                           |
| ----------- | --------------------- | ------------------------------------------------------------------------------------- |
| `spacing`   | `number`              | The space between children, in points. Leave it out for SwiftUI's default spacing.    |
| `alignment` | `HorizontalAlignment` | The horizontal alignment of the children, such as `leading`, `center`, or `trailing`. |

```svelte
<vstack alignment="leading" spacing={4}>
  <txt font="headline">Ada Lovelace</txt>
  <txt color="secondary">Mathematician</txt>
</vstack>
```

### `hstack`

An `HStack`: lays out its children in a horizontal row.

| Attribute   | Type                | Description                                                                                                    |
| ----------- | ------------------- | -------------------------------------------------------------------------------------------------------------- |
| `spacing`   | `number`            | The space between children, in points. Leave it out for SwiftUI's default spacing.                             |
| `alignment` | `VerticalAlignment` | The vertical alignment of the children: `top`, `center`, `bottom`, `firstTextBaseline`, or `lastTextBaseline`. |

```svelte
<hstack alignment="firstTextBaseline" spacing={8}>
  <txt font="largeTitle" weight="bold">72°</txt>
  <txt color="secondary">Sunny</txt>
</hstack>
```

### `zstack`

A `ZStack`: layers its children on top of each other.

| Attribute   | Type             | Description                                                                                                |
| ----------- | ---------------- | ---------------------------------------------------------------------------------------------------------- |
| `alignment` | `LayerAlignment` | The alignment of the children on both axes, such as `center`, `topLeading`, or `leadingFirstTextBaseline`. |

```svelte
<zstack alignment="bottomTrailing">
  <roundedrectangle fill="blue.gradient" width={160} height={100} />
  <txt color="white" weight="semibold" padding={8}>New</txt>
</zstack>
```

### `spacer`

A `Spacer`: takes up the free space along the axis of its stack.

| Attribute   | Type     | Description                                                                     |
| ----------- | -------- | ------------------------------------------------------------------------------- |
| `minlength` | `number` | The minimum length of the spacer in points. It never shrinks below this length. |

```svelte
<hstack padding>
  <txt>Total</txt>
  <spacer minlength={20} />
  <txt weight="semibold">$42.00</txt>
</hstack>
```

### `divider`

A `Divider`: a thin line that separates content.

This element has no attributes of its own.

```svelte
<vstack alignment="leading" spacing={12} padding>
  <txt>Above the line</txt>
  <divider />
  <txt>Below the line</txt>
</vstack>
```

### `grid`

A `Grid`: lays out its `gridrow` children as a table whose columns line up across rows.

| Attribute   | Type             | Description                                                                                              |
| ----------- | ---------------- | -------------------------------------------------------------------------------------------------------- |
| `alignment` | `LayerAlignment` | The alignment of each child within its grid cell, such as `center` or `topLeading`.                      |
| `spacing`   | `number`         | The horizontal and vertical space between cells, in points. `hspacing` and `vspacing` override each one. |
| `hspacing`  | `number`         | The horizontal space between columns, in points. Overrides `spacing`.                                    |
| `vspacing`  | `number`         | The vertical space between rows, in points. Overrides `spacing`.                                         |

```svelte
<grid alignment="leading" hspacing={24} vspacing={8} padding>
  <gridrow>
    <txt weight="semibold">Plan</txt>
    <txt weight="semibold">Price</txt>
  </gridrow>
  <divider />
  <gridrow>
    <txt>Basic</txt>
    <txt>Free</txt>
  </gridrow>
  <gridrow>
    <txt>Pro</txt>
    <txt>$4.99</txt>
  </gridrow>
</grid>
```

### `gridrow`

A `GridRow`: one row of a `grid`.

| Attribute   | Type                | Description                                      |
| ----------- | ------------------- | ------------------------------------------------ |
| `alignment` | `VerticalAlignment` | The vertical alignment of the cells in this row. |

```svelte
<grid spacing={8} padding>
  <gridrow alignment="bottom">
    <txt font="largeTitle">A</txt>
    <txt font="caption">b</txt>
    <txt>c</txt>
  </gridrow>
  <gridrow>
    <txt colspan={2} maxwidth="infinity" background="yellow">Two columns</txt>
    <txt>One</txt>
  </gridrow>
</grid>
```

### `viewthatfits`

A `ViewThatFits`: shows the first child that fits in the available space.

| Attribute | Type                                   | Description                                                    |
| --------- | -------------------------------------- | -------------------------------------------------------------- |
| `axes`    | `"horizontal" \| "vertical" \| "both"` | The axes checked for fit: `horizontal`, `vertical`, or `both`. |

```svelte
<viewthatfits axes="horizontal" padding>
  <hstack>
    <btn variant="bordered">Save the draft</btn>
    <btn variant="prominent">Publish it now</btn>
  </hstack>
  <vstack>
    <btn variant="bordered">Save the draft</btn>
    <btn variant="prominent">Publish it now</btn>
  </vstack>
</viewthatfits>
```

### `group`

A `Group`: applies its modifiers to its children without adding a container.

This element has no attributes of its own.

```svelte
<vstack spacing={8}>
  <group font="headline" color="teal">
    <txt>Both lines</txt>
    <txt>share one style</txt>
  </group>
  <txt>This one doesn't</txt>
</vstack>
```

### `safeareainset`

A `.safeAreaInset`: pins its content to one edge of its parent and insets the rest of the parent's content to make room.

| Attribute   | Type                                       | Description                                                                                            |
| ----------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `edge`      | `Edge`                                     | The edge of the parent to pin the content to: `top`, `bottom` (the default), `leading`, or `trailing`. |
| `alignment` | `HorizontalAlignment \| VerticalAlignment` | The alignment of the content along the edge.                                                           |
| `spacing`   | `number`                                   | The space in points between the content and the rest of the parent's content.                          |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  const rows = Array.from({ length: 30 }, (_, index) => index + 1);
</script>

<scrollview>
  <vstack
    alignment="leading"
    spacing={8}
    padding
    maxwidth="infinity"
    framealignment="leading"
  >
    {#each rows as row (row)}
      <txt>Row {row}</txt>
    {/each}
  </vstack>
  <safeareainset edge="bottom">
    <txt maxwidth="infinity" padding background="thinMaterial">
      Pinned below the rows
    </txt>
  </safeareainset>
</scrollview>
```

### `flowstack`

A wrapping layout: it puts its children in rows and starts a new row when the next child doesn't fit the width, the way words wrap in a paragraph. `spacing` sets the gap between children in a row, `linespacing` sets the gap between rows, and `alignment` sets how each row is aligned.

| Attribute     | Type                                  | Description                                                         |
| ------------- | ------------------------------------- | ------------------------------------------------------------------- |
| `spacing`     | `number`                              | The space between children in a row, in points. Defaults to 8.      |
| `linespacing` | `number`                              | The space between rows, in points. Defaults to `spacing`.           |
| `alignment`   | `"leading" \| "center" \| "trailing"` | How each row sits in the width: `leading`, `center`, or `trailing`. |

```svelte
<script lang="ts">
  const tags = [
    "Svelte",
    "SwiftUI",
    "JavaScriptCore",
    "Layout",
    "Flow",
    "Wrapping rows",
    "Spacing",
    "Alignment",
  ];
</script>

<vstack spacing={16} alignment="leading">
  <flowstack spacing={8} linespacing={12}>
    {#each tags as tag (tag)}
      <txt
        padding={{ horizontal: 10, vertical: 6 }}
        background="blue"
        color="white"
        radius={8}
      >
        {tag}
      </txt>
    {/each}
  </flowstack>
  <flowstack spacing={8} alignment="center">
    {#each tags.slice(0, 5) as tag (tag)}
      <txt
        padding={{ horizontal: 10, vertical: 6 }}
        background="teal"
        color="white"
        radius={8}
      >
        {tag}
      </txt>
    {/each}
  </flowstack>
</vstack>
```

### `reflowstack`

A layout that puts its children in one row when their ideal widths fit the width, and in a column otherwise. It keeps one set of children, so a child with a `matchedid` keeps morphing when the layout switches, which a `viewthatfits` with two copies of the children can't do.

| Attribute   | Type             | Description                                                                                                                                                                                          |
| ----------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `spacing`   | `number`         | The space between children in either direction, in points. Defaults to 8.                                                                                                                            |
| `alignment` | `LayerAlignment` | Where the children sit: the vertical part, such as `top` or `bottom`, aligns them in a row, and the horizontal part, such as `leading` or `trailing`, aligns them in a column. Defaults to `center`. |

```svelte
<vstack spacing={16} alignment="leading">
  <reflowstack spacing={8}>
    <txt
      padding={{ horizontal: 10, vertical: 6 }}
      background="blue"
      color="white"
      radius={8}>Fits</txt
    >
    <txt
      padding={{ horizontal: 10, vertical: 6 }}
      background="blue"
      color="white"
      radius={8}>in a row</txt
    >
  </reflowstack>
  <reflowstack spacing={8} alignment="leading">
    <txt
      padding={{ horizontal: 10, vertical: 6 }}
      background="teal"
      color="white"
      radius={8}>A label that is too long to share a row</txt
    >
    <txt
      padding={{ horizontal: 10, vertical: 6 }}
      background="teal"
      color="white"
      radius={8}>so the stack becomes a column</txt
    >
  </reflowstack>
</vstack>
```

## Scrolling and lazy containers

### `scrollview`

A `ScrollView`: scrolls its children, vertically by default.

| Attribute        | Type                                                         | Description                                                                                                                                       |
| ---------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `indicators`     | `boolean \| "automatic" \| "visible" \| "hidden" \| "never"` | Whether the scroll indicators show: `automatic`, `visible`, `hidden`, or `never`, or a boolean where `false` hides them.                          |
| `bounce`         | `"automatic" \| "always" \| "basedOnSize"`                   | When the content bounces past its edges: `automatic`, `always`, or `basedOnSize`, which bounces only when the content is larger than the view.    |
| `anchor`         | `UnitPointName`                                              | The point the scroll starts at, as a unit point such as `bottom`, which suits a chat.                                                             |
| `onscroll`       | `(scroll: ScrollGeometry) => void`                           | Runs as the content scrolls, with the scroll position and sizes in points.                                                                        |
| `onrefresh`      | `() => Promise<unknown> \| void`                             | Runs when the user pulls to refresh. If it returns a promise, the spinner stays until the promise settles.                                        |
| `scrolldisabled` | `boolean`                                                    | Stops the content from scrolling, and keeps it in place.                                                                                          |
| `onscrollphase`  | `(event: ScrollPhaseEvent) => void`                          | Runs when the scroll phase changes, with `phase`: `idle`, `tracking` (a finger is on the content), `interacting`, `decelerating`, or `animating`. |
| `axes`           | `"vertical" \| "horizontal" \| "both"`                       | The directions in which the content scrolls: `vertical` (the default), `horizontal`, or `both`.                                                   |
| `snap`           | `"paging" \| "view"`                                         | Stops scrolling at each screen-sized page with `paging`, or at the start of each child of the stack inside it with `view`.                        |

```svelte
<script lang="ts">
  import { ref } from "swiftui-svelte";

  const colors = [
    "red",
    "orange",
    "yellow",
    "green",
    "blue",
    "purple",
  ] as const;
  let offset = $state(0);
  const column = ref();
  let locked = $state(false);
  let phase = $state("idle");
  let lastShown = $state(0);
</script>

<vstack spacing={12}>
  <scrollview
    axes="horizontal"
    snap="view"
    indicators={false}
    onscroll={(scroll) => (offset = Math.round(scroll.x))}
  >
    <hstack spacing={12} padding={{ horizontal: 16 }}>
      {#each colors as color (color)}
        <roundedrectangle
          fill={color}
          width={220}
          height={140}
          cornerradius={20}
        />
      {/each}
    </hstack>
  </scrollview>
  <txt font="caption" color="secondary">Scrolled {offset} points</txt>
  <hstack spacing={12}>
    <btn variant="bordered" onclick={() => column.scrollTo({ y: 0 })}>Top</btn>
    <btn
      variant="bordered"
      onclick={() => column.scrollTo({ y: 400 }, { animated: false })}
      >Offset 400</btn
    >
    <btn variant="bordered" onclick={() => (locked = !locked)}>
      {locked ? "Unlock" : "Lock"}
    </btn>
  </hstack>
  <scrollview
    {@attach column}
    height={160}
    scrolldisabled={locked}
    onscrollphase={(event) => (phase = event.phase)}
  >
    <vstack spacing={8} padding>
      {#each Array.from({ length: 20 }, (_, index) => index + 1) as row (row)}
        <txt
          padding
          background="secondarySystemBackground"
          radius={8}
          onscrollvisibility={(event) => {
            if (event.visible) lastShown = row;
          }}>Row {row}</txt
        >
      {/each}
    </vstack>
  </scrollview>
  <txt font="caption" color="secondary">
    Phase: {phase}. Last row shown: {lastShown}.
  </txt>
</vstack>
```

### `lazyvstack`

A `LazyVStack`: a vertical stack that creates its children as they scroll into view.

| Attribute   | Type                  | Description                                                                                                 |
| ----------- | --------------------- | ----------------------------------------------------------------------------------------------------------- |
| `spacing`   | `number`              | The space between children, in points. Leave it out for SwiftUI's default spacing.                          |
| `alignment` | `HorizontalAlignment` | The horizontal alignment of the children, such as `leading`, `center`, or `trailing`.                       |
| `pinned`    | `Pinned`              | Keeps the headers, the footers, or both on screen while their rows scroll: `headers`, `footers`, or `both`. |

```svelte
<script lang="ts">
  const letters = ["A", "B", "C", "D"];
  const numbers = Array.from({ length: 12 }, (_, index) => index + 1);
</script>

<scrollview>
  <lazyvstack alignment="leading" spacing={8} pinned="headers">
    {#each letters as letter (letter)}
      <sectionview>
        <header>
          <txt
            font="headline"
            padding={8}
            maxwidth="infinity"
            framealignment="leading"
            background="bar">{letter}</txt
          >
        </header>
        {#each numbers as number (number)}
          <txt padding={{ horizontal: 8 }}>{letter}{number}</txt>
        {/each}
      </sectionview>
    {/each}
  </lazyvstack>
</scrollview>
```

### `lazyhstack`

A `LazyHStack`: a horizontal stack that creates its children as they scroll into view.

| Attribute   | Type                | Description                                                                                                    |
| ----------- | ------------------- | -------------------------------------------------------------------------------------------------------------- |
| `spacing`   | `number`            | The space between children, in points. Leave it out for SwiftUI's default spacing.                             |
| `alignment` | `VerticalAlignment` | The vertical alignment of the children: `top`, `center`, `bottom`, `firstTextBaseline`, or `lastTextBaseline`. |
| `pinned`    | `Pinned`            | Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`.   |

```svelte
<script lang="ts">
  const items = Array.from({ length: 50 }, (_, index) => index + 1);
</script>

<scrollview axes="horizontal" indicators={false}>
  <lazyhstack spacing={12} padding>
    {#each items as item (item)}
      <zstack width={100} height={100} background="orange.gradient" radius={16}>
        <txt font="title" weight="bold" color="white">{item}</txt>
      </zstack>
    {/each}
  </lazyhstack>
</scrollview>
```

### `lazyvgrid`

A `LazyVGrid`: a grid of columns that creates its children as they scroll into view.

| Attribute   | Type                        | Description                                                                                                                                                                                                                                                    |
| ----------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `columns`   | `number \| Array<GridItem>` | The columns: a number of equal flexible columns, or an array of column items. An item is a number for a fixed width, `{ min, max }` for a flexible column, `{ fixed }` for a fixed width, or `{ adaptive }` for as many columns of at least that width as fit. |
| `spacing`   | `number`                    | The space between columns and rows, in points.                                                                                                                                                                                                                 |
| `alignment` | `HorizontalAlignment`       | The horizontal alignment of the content in each column.                                                                                                                                                                                                        |
| `pinned`    | `Pinned`                    | Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`.                                                                                                                                                   |

```svelte
<script lang="ts">
  const symbols = [
    "sun.max",
    "moon",
    "cloud",
    "cloud.rain",
    "snowflake",
    "wind",
    "bolt",
    "rainbow",
    "tornado",
    "thermometer.sun",
    "umbrella",
    "drop",
  ];
</script>

<scrollview>
  <lazyvgrid columns={[{ adaptive: 80 }]} spacing={12} padding>
    {#each symbols as name (name)}
      <sfsymbol
        {name}
        font="title"
        width={80}
        height={80}
        background="secondarySystemBackground"
        radius={12}
      />
    {/each}
  </lazyvgrid>
</scrollview>
```

### `lazyhgrid`

A `LazyHGrid`: a grid of rows that creates its children as they scroll into view.

| Attribute   | Type                        | Description                                                                                                                                                                                                                                        |
| ----------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rows`      | `number \| Array<GridItem>` | The rows: a number of equal flexible rows, or an array of row items. An item is a number for a fixed height, `{ min, max }` for a flexible row, `{ fixed }` for a fixed height, or `{ adaptive }` for as many rows of at least that height as fit. |
| `spacing`   | `number`                    | The space between rows and columns, in points.                                                                                                                                                                                                     |
| `alignment` | `VerticalAlignment`         | The vertical alignment of the content in each row.                                                                                                                                                                                                 |
| `pinned`    | `Pinned`                    | Keeps the headers, the footers, or both on screen while their items scroll: `headers`, `footers`, or `both`.                                                                                                                                       |

```svelte
<script lang="ts">
  const numbers = Array.from({ length: 60 }, (_, index) => index + 1);
</script>

<scrollview axes="horizontal">
  <lazyhgrid rows={3} spacing={12} padding height={240}>
    {#each numbers as number (number)}
      <txt width={60} height={60} background="mint" radius={8}>{number}</txt>
    {/each}
  </lazyhgrid>
</scrollview>
```

## Lists and forms

### `list`

A `List`: a scrolling list of rows that can be selected, edited, and refreshed.

| Attribute           | Type                                                                                                | Description                                                                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `indicators`        | `boolean \| "automatic" \| "visible" \| "hidden" \| "never"`                                        | Whether the scroll indicators show: `automatic`, `visible`, `hidden`, or `never`, or a boolean where `false` hides them.                          |
| `bounce`            | `"automatic" \| "always" \| "basedOnSize"`                                                          | When the content bounces past its edges: `automatic`, `always`, or `basedOnSize`, which bounces only when the content is larger than the view.    |
| `anchor`            | `UnitPointName`                                                                                     | The point the scroll starts at, as a unit point such as `bottom`, which suits a chat.                                                             |
| `onscroll`          | `(scroll: ScrollGeometry) => void`                                                                  | Runs as the content scrolls, with the scroll position and sizes in points.                                                                        |
| `onrefresh`         | `() => Promise<unknown> \| void`                                                                    | Runs when the user pulls to refresh. If it returns a promise, the spinner stays until the promise settles.                                        |
| `scrolldisabled`    | `boolean`                                                                                           | Stops the content from scrolling, and keeps it in place.                                                                                          |
| `onscrollphase`     | `(event: ScrollPhaseEvent) => void`                                                                 | Runs when the scroll phase changes, with `phase`: `idle`, `tracking` (a finger is on the content), `interacting`, `decelerating`, or `animating`. |
| `ondelete`          | `(indices: Array<number>) => void`                                                                  | Runs when the user deletes rows, with the positions of the deleted rows among the element's children.                                             |
| `onmove`            | `(move: RowMove) => void`                                                                           | Runs when the user moves a row, with the rows that moved and the position they moved to.                                                          |
| `multiple`          | `false \| true`                                                                                     | Set to `false`, or leave it out, to allow only one selected row. Set to `true` to let the user select several rows.                               |
| `selection`         | `string \| number \| null \| Array<string \| number>`                                               | The `tag` of the selected row, or `null` when nothing is selected. The `tag`s of the selected rows.                                               |
| `onselectionchange` | `((selection: string \| number \| null) => void) \| ((selection: Array<string \| number>) => void)` | Runs when the selection changes, with the selected row's `tag`, or `null`. Runs when the selection changes, with the array of selected `tag`s.    |
| `variant`           | `"automatic" \| "plain" \| "inset" \| "grouped" \| "insetGrouped" \| "sidebar"`                     | The list style: `automatic`, `plain`, `inset`, `grouped`, `insetGrouped`, or `sidebar`.                                                           |
| `editing`           | `boolean`                                                                                           | Turns edit mode on or off. Use `bind:editing` with the `List` component to bind it.                                                               |
| `oneditingchange`   | `(editing: boolean) => void`                                                                        | Runs when SwiftUI turns edit mode on or off, with the new `editing` value.                                                                        |
| `sectionindex`      | `BarVisibility`                                                                                     | Shows or hides the section index along the trailing edge, for sections that have an `indexlabel`.                                                 |

```svelte
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
```

### `sectionview`

A `Section`: groups rows under an optional `header` and `footer`, in a `formview` or a `list`.

| Attribute    | Type                               | Description                                                                                           |
| ------------ | ---------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `ondelete`   | `(indices: Array<number>) => void` | Runs when the user deletes rows, with the positions of the deleted rows among the element's children. |
| `onmove`     | `(move: RowMove) => void`          | Runs when the user moves a row, with the rows that moved and the position they moved to.              |
| `header`     | `string`                           | The header shown above the rows. A `header` child can replace it with custom content.                 |
| `footer`     | `string`                           | The footer shown below the rows. A `footer` child can replace it with custom content.                 |
| `indexlabel` | `string`                           | A letter for this section in the list's section index, on iOS 26 and later.                           |

```svelte
<list>
  <sectionview header="Fruits" footer="In season this week.">
    <txt>Apples</txt>
    <txt>Pears</txt>
  </sectionview>
  <sectionview>
    <header>
      <labelview title="Vegetables" symbol="carrot" />
    </header>
    <txt>Carrots</txt>
  </sectionview>
</list>
```

### `swipeactions`

A `.swipeActions` modifier that adds its `btn` children as the swipe actions of the enclosing list row.

| Attribute | Type                      | Description                                                              |
| --------- | ------------------------- | ------------------------------------------------------------------------ |
| `edge`    | `"leading" \| "trailing"` | The edge of the row that the swipe starts from: `leading` or `trailing`. |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let messages = $state(["Lunch?", "Invoice", "Photos"]);
  let flagged: Array<string> = $state([]);

  function toggleFlag(message: string) {
    flagged = flagged.includes(message)
      ? flagged.filter((other) => other !== message)
      : [...flagged, message];
  }
</script>

<list>
  {#each messages as message (message)}
    <hstack>
      <txt>{message}</txt>
      {#if flagged.includes(message)}
        <spacer />
        <sfsymbol name="flag.fill" color="orange" label="Flagged" />
      {/if}
      <swipeactions>
        <btn
          role="destructive"
          onclick={() =>
            (messages = messages.filter((other) => other !== message))}
        >
          <labelview title="Delete" symbol="trash" />
        </btn>
      </swipeactions>
      <swipeactions edge="leading">
        <btn tint="orange" onclick={() => toggleFlag(message)}>
          <labelview title="Flag" symbol="flag" />
        </btn>
      </swipeactions>
    </hstack>
  {/each}
</list>
```

### `formview`

A `Form`: a screen with the grouped look of the Settings app.

This element has no attributes of its own.

```svelte
<script lang="ts">
  let name = $state("");
  let notifications = $state(true);
</script>

<formview>
  <sectionview header="Profile">
    <textfield
      placeholder="Name"
      value={name}
      oninput={(value) => (name = value)}
    />
  </sectionview>
  <sectionview header="Preferences" footer="You can change this later.">
    <toggle checked={notifications} onchange={(next) => (notifications = next)}>
      Notifications
    </toggle>
  </sectionview>
</formview>
```

### `labeledcontent`

A `LabeledContent`: shows a title with a value on the trailing side, like a row in Settings.

| Attribute | Type               | Description                                                               |
| --------- | ------------------ | ------------------------------------------------------------------------- |
| `title`   | `string`           | The label on the leading side. Use a `label` child for a custom label.    |
| `value`   | `string \| number` | The value on the trailing side. Without it, the children are the content. |

```svelte
<formview>
  <labeledcontent title="Version" value="1.0.0" />
  <labeledcontent title="Storage" value="12.4 GB" />
  <labeledcontent title="Status">
    <txt color="green">Up to date</txt>
  </labeledcontent>
</formview>
```

### `disclosuregroup`

A `DisclosureGroup`: shows its children when the user expands it.

| Attribute  | Type                          | Description                                                                                         |
| ---------- | ----------------------------- | --------------------------------------------------------------------------------------------------- |
| `title`    | `string`                      | The title of the group. Use a `label` child for a custom title.                                     |
| `expanded` | `boolean`                     | Whether the group is expanded. Use `bind:expanded` with the `DisclosureGroup` component to bind it. |
| `ontoggle` | `(expanded: boolean) => void` | Runs when the user expands or collapses the group, with the new `expanded` value.                   |

```svelte
<script lang="ts">
  let expanded = $state(false);
  let logging = $state(false);
</script>

<formview>
  <disclosuregroup
    title="Advanced"
    {expanded}
    ontoggle={(next) => (expanded = next)}
  >
    <toggle checked={logging} onchange={(next) => (logging = next)}>
      Debug logging
    </toggle>
  </disclosuregroup>
</formview>
```

### `groupbox`

A `GroupBox`: draws its children in a box.

| Attribute | Type     | Description                                                            |
| --------- | -------- | ---------------------------------------------------------------------- |
| `title`   | `string` | The title shown above the box. Use a `label` child for a custom title. |

```svelte
<groupbox title="Storage" padding>
  <progressview value={0.62}>
    <txt>62 GB of 100 GB used</txt>
  </progressview>
</groupbox>
```

### `controlgroup`

A `ControlGroup`: joins its controls, such as buttons, into one control.

| Attribute | Type     | Description                                                     |
| --------- | -------- | --------------------------------------------------------------- |
| `title`   | `string` | The title of the group. Use a `label` child for a custom title. |

```svelte
<script lang="ts">
  let zoom = $state(100);
</script>

<vstack spacing={12}>
  <controlgroup title="Zoom">
    <btn onclick={() => (zoom -= 10)}>
      <sfsymbol name="minus.magnifyingglass" label="Zoom out" />
    </btn>
    <btn onclick={() => (zoom += 10)}>
      <sfsymbol name="plus.magnifyingglass" label="Zoom in" />
    </btn>
  </controlgroup>
  <txt color="secondary">{zoom}%</txt>
</vstack>
```

## Text and images

### `txt`

A `Text`: displays text. Its `txt` children style spans of it, and it can render Markdown.

| Attribute         | Type                                  | Description                                                                                                                                          |
| ----------------- | ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lines`           | `number`                              | The maximum number of lines. Leave it out for no limit.                                                                                              |
| `align`           | `"leading" \| "center" \| "trailing"` | The alignment of wrapped lines: `leading`, `center`, or `trailing`.                                                                                  |
| `underline`       | `boolean`                             | Underlines the text.                                                                                                                                 |
| `strikethrough`   | `boolean`                             | Draws a line through the text.                                                                                                                       |
| `href`            | `string`                              | Makes the text a link that opens this URL in the browser.                                                                                            |
| `markdown`        | `boolean \| string`                   | Renders the text as inline Markdown: bold, italic, strikethrough, code, and links. Set it with no value to use the element's own text as the source. |
| `whitespace`      | `"normal" \| "pre-line" \| "pre"`     | How spaces and line breaks are handled: `normal` collapses them, `pre-line` keeps line breaks, and `pre` keeps every space.                          |
| `kerning`         | `number`                              | Adjusts the space between letters, in points.                                                                                                        |
| `tracking`        | `number`                              | Adjusts the tracking of the text, which is the space between letters, in points.                                                                     |
| `baselineoffset`  | `number`                              | Moves the text up or down from the baseline, in points. A positive value raises the text, and a negative value lowers it.                            |
| `underlinestyle`  | `"solid" \| "dotted" \| "dashed"`     | The line style of the underline: `solid`, `dotted`, or `dashed`. Applies when `underline` is set.                                                    |
| `underlinecolor`  | `Color`                               | The color of the underline. Applies when `underline` is set.                                                                                         |
| `monospaceddigit` | `boolean`                             | Uses digits of equal width, so numbers that change don't shift the text around them.                                                                 |
| `linespacing`     | `number`                              | The extra space between lines, in points.                                                                                                            |
| `truncation`      | `"head" \| "middle" \| "tail"`        | Where the text is cut off when it doesn't fit: `head`, `middle`, or `tail`.                                                                          |
| `minscale`        | `number`                              | The smallest fraction of the font size that the text can shrink to before it's truncated, such as `0.5`.                                             |
| `selectable`      | `boolean`                             | Lets the user select and copy the text.                                                                                                              |

```svelte
<vstack alignment="leading" spacing={12} padding>
  <txt font="title" weight="bold">Rich text</txt>
  <txt color="secondary">
    Spans can be <txt weight="bold" color="primary">bold</txt>,
    <txt italic>italic</txt>, or
    <txt href="https://svelte.dev" underline>links</txt>.
  </txt>
  <txt markdown="Markdown works **too**, with `code` and _emphasis_."></txt>
  <txt lines={1} truncation="middle">
    A long line of text that gets cut off in the middle when it doesn't fit
  </txt>
  <txt selectable font="footnote" tracking={2}>SELECT AND COPY ME</txt>
  <txt font="body"
    >Footnote<txt baselineoffset={6} font="caption">1</txt> and
    <txt underline underlinestyle="dotted" underlinecolor="red">dotted</txt>
    and
    <txt underline underlinestyle="dashed" underlinecolor="blue">dashed</txt>
    underlines.</txt
  >
  <txt monospaceddigit font="title2">12:34</txt>
  <txt font="body"
    >Spans can use <txt fontname="Georgia-Italic">Georgia italic</txt> too.</txt
  >
  <txt fontname="Georgia" size={20} lang="tr">grafik geçmiş</txt>
</vstack>
```

### `sfsymbol`

An SF Symbol, rendered as an `Image(systemName:)`.

| Attribute   | Type                                                                                     | Description                                                                                                                                                 |
| ----------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`      | `string`                                                                                 | The SF Symbol name, such as `trash` or `wifi`.                                                                                                              |
| `label`     | `string`                                                                                 | The accessibility label that VoiceOver reads, such as `Delete to-do`. Without it, VoiceOver reads the symbol's built-in description.                        |
| `value`     | `number`                                                                                 | A value from 0 to 1 that fills a variable symbol, such as `wifi`, part of the way.                                                                          |
| `variant`   | `SymbolVariant \| `${SymbolVariant} ${SymbolVariant}``                                   | Symbol variants: `fill`, `slash`, `circle`, `square`, or `rectangle`. Combine them with a space, such as `circle fill`.                                     |
| `rendering` | `"monochrome" \| "hierarchical" \| "palette" \| "multicolor"`                            | The rendering mode: `monochrome`, `hierarchical`, `palette`, or `multicolor`.                                                                               |
| `colors`    | `Array<Color>`                                                                           | Up to three colors for the `palette` rendering mode.                                                                                                        |
| `effect`    | `"bounce" \| "pulse" \| "variableColor" \| "breathe" \| "rotate" \| "wiggle" \| "scale"` | An animation for the symbol: `bounce`, `pulse`, `variableColor`, `breathe`, `rotate`, `wiggle`, or `scale`. Repeating effects run while `active` is `true`. |
| `trigger`   | `string \| number \| boolean`                                                            | A value that plays `effect` once each time it changes. `bounce` works only this way, and `scale` ignores it.                                                |
| `active`    | `boolean`                                                                                | Whether a repeating `effect` runs. Defaults to `true`.                                                                                                      |

```svelte
<script lang="ts">
  let rings = $state(0);
</script>

<hstack spacing={20} font="largeTitle">
  <sfsymbol name="heart" variant="circle fill" color="pink" />
  <sfsymbol name="wifi" value={0.5} label="Wi-Fi at half strength" />
  <sfsymbol
    name="cloud.sun.rain"
    rendering="palette"
    colors={["gray", "yellow", "blue"]}
  />
  <btn onclick={() => rings++}>
    <sfsymbol name="bell" effect="bounce" trigger={rings} label="Ring" />
  </btn>
</hstack>
```

### `labelview`

A `Label`: shows a title with an icon.

| Attribute | Type                                                         | Description                                                                    |
| --------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `title`   | `string`                                                     | The title of the label.                                                        |
| `symbol`  | `string`                                                     | The SF Symbol name for the icon.                                               |
| `image`   | `string`                                                     | The name of an asset-catalog image for the icon.                               |
| `variant` | `"automatic" \| "titleOnly" \| "iconOnly" \| "titleAndIcon"` | What the label shows: `automatic`, `titleOnly`, `iconOnly`, or `titleAndIcon`. |

```svelte
<vstack alignment="leading" spacing={12}>
  <labelview title="Favorites" symbol="star.fill" />
  <labelview title="swiftui-svelte" image="Logo" />
  <labelview title="Alerts" symbol="bell" variant="iconOnly" />
</vstack>
```

### `icon`

The icon of a `labelview`. Its children are the icon.

This element has no attributes of its own.

This element doesn't take modifiers.

```svelte
<labelview title="Online">
  <icon>
    <circleshape fill="green" width={10} height={10} />
  </icon>
</labelview>
```

### `imageview`

An `Image`: shows an image from the asset catalog or the app bundle.

| Attribute       | Type                                     | Description                                                                                                                                             |
| --------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`          | `string`                                 | The name of an image in the asset catalog.                                                                                                              |
| `file`          | `string`                                 | The path of an image file in the app bundle, such as `photos/beach.jpg`.                                                                                |
| `fit`           | `"fit" \| "fill" \| "stretch" \| "tile"` | How the image is scaled into its frame: `fit`, `fill`, `stretch`, or `tile`. Without it, the image keeps its own size.                                  |
| `renderingmode` | `"original" \| "template"`               | `template` draws the image in the foreground color, and `original` draws it as it is.                                                                   |
| `interpolation` | `"none" \| "low" \| "medium" \| "high"`  | How smoothly the image is scaled: `none`, `low`, `medium`, or `high`. Use `high` for logos and other raster art drawn much smaller than its pixel size. |
| `label`         | `string`                                 | The accessibility label that VoiceOver reads. Without it, VoiceOver reads the name of an asset-catalog image.                                           |
| `decorative`    | `boolean`                                | Hides the image from VoiceOver.                                                                                                                         |

```svelte
<hstack spacing={16}>
  <imageview
    name="Logo"
    fit="fit"
    width={64}
    height={64}
    label="swiftui-svelte logo"
  />
  <imageview
    file="logo-mono.png"
    fit="fit"
    width={64}
    height={64}
    renderingmode="template"
    color="teal"
    decorative
  />
</hstack>
```

### `asyncimage`

An `AsyncImage`: loads an image from `src` and shows it in the element's frame.

| Attribute | Type                                     | Description                                                                                                                                                    |
| --------- | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src`     | `string`                                 | The URL of the image to load.                                                                                                                                  |
| `fit`     | `"fit" \| "fill" \| "stretch" \| "tile"` | Scales the image: `fit` keeps its proportions inside the frame, `fill` covers the frame, `stretch` fills it exactly, and `tile` repeats it. Defaults to `fit`. |
| `onload`  | `() => void`                             | Runs when the image has loaded and appears.                                                                                                                    |
| `onerror` | `(message: string) => void`              | Runs when the image can't be loaded, with the error message.                                                                                                   |

```svelte
<script lang="ts">
  let status = $state("Loading");
</script>

<vstack spacing={8}>
  <asyncimage
    src="https://github.com/sveltejs.png"
    fit="fill"
    width={120}
    height={120}
    radius={24}
    onload={() => (status = "Loaded")}
    onerror={(message) => (status = message)}
  />
  <txt font="caption" color="secondary">{status}</txt>
</vstack>
```

### `placeholder`

The content that an `asyncimage` shows while the image loads. Its children are the content.

This element has no attributes of its own.

This element doesn't take modifiers.

```svelte
<asyncimage
  src="https://github.com/sveltejs.png?size=480"
  width={120}
  height={120}
  radius={24}
>
  <placeholder>
    <roundedrectangle fill="quaternarySystemFill" cornerradius={24} />
  </placeholder>
</asyncimage>
```

### `failure`

The content that an `asyncimage` shows when the image can't be loaded. Its children are the content.

This element has no attributes of its own.

This element doesn't take modifiers.

```svelte
<asyncimage src="https://example.invalid/photo.jpg" width={120} height={120}>
  <failure>
    <vstack spacing={4}>
      <sfsymbol
        name="photo.badge.exclamationmark"
        font="title"
        color="secondary"
      />
      <txt font="caption" color="secondary">Couldn't load the photo</txt>
    </vstack>
  </failure>
</asyncimage>
```

### `contentunavailableview`

A `ContentUnavailableView`: an empty state with a symbol, a title, a description, and optional action buttons.

| Attribute     | Type                      | Description                                                                           |
| ------------- | ------------------------- | ------------------------------------------------------------------------------------- |
| `title`       | `string`                  | The title of the empty state.                                                         |
| `symbol`      | `string`                  | The SF Symbol shown above the title.                                                  |
| `description` | `string`                  | Explanatory text shown below the title.                                               |
| `variant`     | `"automatic" \| "search"` | `search` shows the system's "No Results" message, and mentions `query` when it's set. |
| `query`       | `string`                  | The search text to mention in the `search` message.                                   |

```svelte
<contentunavailableview
  title="No favorites"
  symbol="star"
  description="Tap the star on any item to keep it here."
>
  <btn variant="bordered">Browse items</btn>
</contentunavailableview>
```

## Controls

### `btn`

A `Button`: runs `onclick` when tapped.

| Attribute     | Type                                                                                                 | Description                                                                                                                                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `variant`     | `"automatic" \| "borderless" \| "plain" \| "bordered" \| "prominent" \| "glass" \| "glassProminent"` | The button style: `automatic`, `borderless` (the default), `plain`, `bordered`, `prominent`, `glass`, or `glassProminent`. The glass styles need iOS 26 and fall back to `bordered` and `prominent` on earlier versions. |
| `role`        | `"destructive" \| "cancel" \| "confirm" \| "close"`                                                  | The role of the button: `destructive` or `cancel`, or `confirm` and `close` on iOS 26 and later.                                                                                                                         |
| `bordershape` | `"automatic" \| "capsule" \| "roundedRectangle" \| "circle" \| number`                               | The shape of a bordered or glass button: `automatic`, `capsule`, `roundedRectangle`, `circle`, or a corner radius in points.                                                                                             |
| `repeat`      | `boolean`                                                                                            | Runs `onclick` again and again while the button is held down, as a stepper does.                                                                                                                                         |
| `onclick`     | `() => void`                                                                                         | Runs when the button is tapped.                                                                                                                                                                                          |

```svelte
<script lang="ts">
  let count = $state(0);
</script>

<vstack spacing={12}>
  <txt font="largeTitle" weight="bold">{count}</txt>
  <btn variant="prominent" onclick={() => count++}>Add one</btn>
  <btn variant="bordered" bordershape="capsule" repeat onclick={() => count++}>
    Hold to keep adding
  </btn>
  <btn variant="glass" role="destructive" onclick={() => (count = 0)}>Reset</btn
  >
  <btn
    pressed={{
      scale: 0.95,
      opacity: 0.8,
      colormultiply: "#dddddd",
      shadow: false,
      animation: "snappy",
    }}
    hovered={{
      brightness: 0.1,
      shadow: { color: "#00000033", radius: 8, y: 4 },
      animation: {
        type: "timingCurve",
        curve: [0.42, 0, 0.58, 1],
        duration: 200,
      },
    }}
    onclick={() => count++}
  >
    <txt
      color="white"
      background="blue"
      radius={8}
      shadow={{ color: "#00000026", radius: 2, y: 1 }}
      padding={{ horizontal: 16, vertical: 8 }}
    >
      Press feedback
    </txt>
  </btn>
  <btn onclick={() => count++}>
    <zstack>
      <hstack
        spacing={8}
        padding={{ horizontal: 16, vertical: 12 }}
        background="white"
        radius={12}
        shadow={{ color: "#00000033", radius: 6, y: 3 }}
        pressed={{ shadow: false }}
        hovered={{ lighten: 0.125 }}
      >
        <txt color="black" pressed={{ color: "red" }}>Nested press</txt>
        <sfsymbol name="arrow.right" hovered={{ offset: { x: 2 } }} />
      </hstack>
      <rectangle
        background="clear"
        radius={12}
        insetshadow
        opacity={0}
        pressed={{ opacity: 1 }}
      />
    </zstack>
  </btn>
</vstack>
```

### `linkview`

A `Link`: opens its `href` in the browser when tapped.

| Attribute | Type     | Description                                                       |
| --------- | -------- | ----------------------------------------------------------------- |
| `href`    | `string` | The URL to open in the browser.                                   |
| `title`   | `string` | The text of the link. Use children instead to set a custom label. |

```svelte
<vstack spacing={12}>
  <linkview href="https://svelte.dev" title="Svelte" />
  <linkview href="https://developer.apple.com/xcode/swiftui/">
    <labelview title="SwiftUI" symbol="swift" />
  </linkview>
</vstack>
```

### `sharelink`

A `ShareLink`: opens the share sheet for its `item` when tapped.

| Attribute | Type     | Description                                                       |
| --------- | -------- | ----------------------------------------------------------------- |
| `item`    | `string` | The URL or text to share.                                         |
| `subject` | `string` | The subject line of a shared email.                               |
| `message` | `string` | The message that is shared with the item.                         |
| `title`   | `string` | The text of the link. Use children instead to set a custom label. |

```svelte
<sharelink
  item="https://svelte.dev"
  subject="Svelte"
  message="Have a look at Svelte."
>
  <labelview title="Share Svelte" symbol="square.and.arrow.up" />
</sharelink>
```

### `menuview`

A `Menu`: opens a menu of its children when tapped.

| Attribute         | Type                                            | Description                                                                             |
| ----------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| `title`           | `string`                                        | The label of the menu, shown with `symbol`. Use a `label` child for a custom label.     |
| `symbol`          | `string`                                        | The SF Symbol shown beside the title.                                                   |
| `variant`         | `"automatic" \| "button" \| "borderlessButton"` | The menu button style: `automatic`, `button`, or `borderlessButton`.                    |
| `order`           | `"automatic" \| "fixed" \| "priority"`          | The order of the menu items: `automatic`, `fixed`, or `priority`.                       |
| `onprimaryaction` | `() => void`                                    | Runs when the menu is tapped, instead of opening it. A long press still opens the menu. |

```svelte
<script lang="ts">
  let sort = $state<string | number>("name");
  let action = $state("none yet");
</script>

<vstack spacing={12}>
  <menuview title="Options" symbol="ellipsis.circle">
    <btn onclick={() => (action = "Duplicate")}>
      <labelview title="Duplicate" symbol="plus.square.on.square" />
    </btn>
    <picker label="Sort by" value={sort} onchange={(value) => (sort = value)}>
      <choice value="name">Name</choice>
      <choice value="date">Date</choice>
    </picker>
    <menuview title="More">
      <btn onclick={() => (action = "Archive")}>Archive</btn>
    </menuview>
    <divider />
    <btn role="destructive" onclick={() => (action = "Delete")}>
      <labelview title="Delete" symbol="trash" />
    </btn>
  </menuview>
  <txt font="caption" color="secondary">Last action: {action}</txt>
</vstack>
```

### `toggle`

A `Toggle`: an on-off control, drawn as a switch, a checkbox, or a button.

| Attribute  | Type                                                | Description                                                                                                                                                         |
| ---------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `checked`  | `boolean`                                           | Whether the toggle is on. Use `bind:checked` with the `Toggle` component to bind it.                                                                                |
| `variant`  | `"automatic" \| "switch" \| "button" \| "checkbox"` | The toggle style: `automatic`, `switch`, `button`, or `checkbox`. `switch` always draws a switch, and `button` draws a button that stays highlighted while it's on. |
| `onchange` | `(checked: boolean) => void`                        | Runs when the user turns the toggle on or off, with the new `checked` value.                                                                                        |

```svelte
<script lang="ts">
  let wifi = $state(true);
  let bold = $state(false);
</script>

<formview>
  <toggle checked={wifi} onchange={(next) => (wifi = next)}>Wi-Fi</toggle>
  <toggle checked={bold} variant="button" onchange={(next) => (bold = next)}>
    <labelview title="Bold" symbol="bold" />
  </toggle>
</formview>
```

### `slider`

A `Slider`: lets the user pick a number between `min` and `max`.

| Attribute  | Type                      | Description                                                     |
| ---------- | ------------------------- | --------------------------------------------------------------- |
| `value`    | `number`                  | The current value of the slider.                                |
| `min`      | `number`                  | The lowest value. Defaults to 0.                                |
| `max`      | `number`                  | The highest value. Defaults to 1.                               |
| `step`     | `number`                  | Snaps the value to multiples of this number.                    |
| `oninput`  | `(value: number) => void` | Runs while the user drags the slider, with the new value.       |
| `onchange` | `(value: number) => void` | Runs when the user lets go of the slider, with the final value. |

```svelte
<script lang="ts">
  let volume = $state(0.5);
  let rating = $state(3);
</script>

<formview>
  <slider value={volume} oninput={(value) => (volume = value)}>
    <txt>Volume</txt>
  </slider>
  <slider
    value={rating}
    min={1}
    max={5}
    step={1}
    onchange={(value) => (rating = value)}
  >
    <txt>Rating</txt>
  </slider>
  <txt color="secondary">
    Volume {Math.round(volume * 100)}%, rating {rating}
  </txt>
</formview>
```

### `stepper`

A `Stepper`: changes a number by `step` with plus and minus buttons.

| Attribute  | Type                      | Description                                                  |
| ---------- | ------------------------- | ------------------------------------------------------------ |
| `value`    | `number`                  | The current value of the stepper.                            |
| `min`      | `number`                  | The lowest value. Without it, there's no lower limit.        |
| `max`      | `number`                  | The highest value. Without it, there's no upper limit.       |
| `step`     | `number`                  | The amount that each press adds or subtracts. Defaults to 1. |
| `onchange` | `(value: number) => void` | Runs when the value changes, with the new value.             |

```svelte
<script lang="ts">
  let guests = $state(2);
</script>

<formview>
  <stepper
    value={guests}
    min={1}
    max={10}
    onchange={(value) => (guests = value)}
  >
    <txt>{guests} guests</txt>
  </stepper>
</formview>
```

### `progressview`

A `ProgressView`: shows a bar filled to `value` out of `total`, or a spinner when there's no `value`.

| Attribute | Type     | Description                                                     |
| --------- | -------- | --------------------------------------------------------------- |
| `value`   | `number` | The progress so far, up to `total`. Leave it out for a spinner. |
| `total`   | `number` | The value that means complete. Defaults to 1.                   |

```svelte
<script lang="ts">
  let uploaded = $state(3);
</script>

<vstack spacing={16} padding>
  <progressview value={uploaded} total={10}>
    <txt>{uploaded} of 10 files</txt>
  </progressview>
  <btn variant="bordered" onclick={() => (uploaded = (uploaded + 1) % 11)}>
    Upload one more
  </btn>
  <progressview>
    <txt>Loading</txt>
  </progressview>
</vstack>
```

### `gauge`

A `Gauge`: shows a value between `min` and `max` on a circular or linear scale.

| Attribute  | Type                                                                              | Description                                                                                  |
| ---------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `value`    | `number`                                                                          | The current value, kept between `min` and `max`.                                             |
| `min`      | `number`                                                                          | The lowest value. Defaults to 0.                                                             |
| `max`      | `number`                                                                          | The highest value. Defaults to 1.                                                            |
| `current`  | `string`                                                                          | Short text shown for the current value.                                                      |
| `minlabel` | `string`                                                                          | Short text shown at the low end of the gauge.                                                |
| `maxlabel` | `string`                                                                          | Short text shown at the high end of the gauge.                                               |
| `variant`  | `"automatic" \| "circular" \| "circularCapacity" \| "linear" \| "linearCapacity"` | The gauge style: `automatic`, `circular`, `circularCapacity`, `linear`, or `linearCapacity`. |

```svelte
<hstack spacing={24} padding>
  <gauge value={0.7} variant="circularCapacity" current="70%">
    <txt>Battery</txt>
  </gauge>
  <gauge
    value={21}
    min={0}
    max={40}
    variant="circular"
    current="21°"
    minlabel="0"
    maxlabel="40"
  >
    <txt>Temperature</txt>
  </gauge>
  <gauge value={0.4} variant="linearCapacity" width={120}>
    <txt>Storage</txt>
  </gauge>
</hstack>
```

## Text input

### `textfield`

A `TextField`: an editable text field, or a number field when `format` is set.

| Attribute          | Type                                                                                                                                                                                                                                                                                                                                                           | Description                                                                                                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `placeholder`      | `string`                                                                                                                                                                                                                                                                                                                                                       | The text shown in the field while it's empty.                                                                                                                                         |
| `placeholdercolor` | `ShapeStyle`                                                                                                                                                                                                                                                                                                                                                   | The color of the placeholder text, such as a named color or a CSS color. Without it, the placeholder uses the system's secondary color.                                               |
| `focused`          | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether the field has keyboard focus. Use `bind:focused` with the `TextField` component to bind it.                                                                                   |
| `keyboard`         | `"default" \| "ascii" \| "numbersAndPunctuation" \| "url" \| "number" \| "phone" \| "namePhone" \| "email" \| "decimal" \| "twitter" \| "webSearch" \| "asciiNumber"`                                                                                                                                                                                          | The keyboard to show, such as `email`, `url`, `number`, `decimal`, or `phone`.                                                                                                        |
| `contenttype`      | `"name" \| "givenName" \| "middleName" \| "familyName" \| "nickname" \| "jobTitle" \| "organization" \| "email" \| "phone" \| "url" \| "username" \| "password" \| "newPassword" \| "oneTimeCode" \| "streetAddress" \| "addressLine1" \| "addressLine2" \| "city" \| "state" \| "postalCode" \| "country" \| "creditCardNumber" \| "location" \| "birthdate"` | What the text is, such as `email`, `username`, `password`, or `oneTimeCode`, so iOS can offer AutoFill and saved passwords.                                                           |
| `autocapitalize`   | `"never" \| "words" \| "sentences" \| "characters"`                                                                                                                                                                                                                                                                                                            | How the text is capitalized: `never`, `words`, `sentences`, or `characters`.                                                                                                          |
| `autocorrect`      | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether autocorrection is on. Set it to `false` to turn it off.                                                                                                                       |
| `submitlabel`      | `"done" \| "go" \| "send" \| "join" \| "route" \| "search" \| "return" \| "next" \| "continue"`                                                                                                                                                                                                                                                                | The label on the Return key, such as `done`, `go`, `next`, `search`, or `send`.                                                                                                       |
| `onsubmit`         | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the user presses Return, after any pending input is sent.                                                                                                                   |
| `onfocus`          | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field gains keyboard focus.                                                                                                                                             |
| `onblur`           | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field loses keyboard focus.                                                                                                                                             |
| `value`            | `string \| number \| null`                                                                                                                                                                                                                                                                                                                                     | The text in the field. Leave it out to let the field keep whatever the user types. The number in the field, or `null` when it's empty.                                                |
| `debounce`         | `number`                                                                                                                                                                                                                                                                                                                                                       | Milliseconds to wait after the user stops typing before `oninput` runs. Defaults to 0, which runs it on every keystroke.                                                              |
| `oninput`          | `((value: string) => void) \| ((value: number \| null) => void)`                                                                                                                                                                                                                                                                                               | Runs with the new text on each keystroke, or after the `debounce` delay. Runs when the user presses Return or leaves the field, with the parsed number, or `null` if they cleared it. |
| `format`           | `NumberFormat`                                                                                                                                                                                                                                                                                                                                                 | Leave out `format` for a text field. How the number is formatted: `number`, `integer`, `percent`, or `{ currency }` with an ISO currency code, such as `EUR`.                         |
| `variant`          | `FieldVariant`                                                                                                                                                                                                                                                                                                                                                 | The look of the field: `automatic`, `plain`, or `roundedBorder`.                                                                                                                      |
| `lines`            | `number \| [ number, number ]`                                                                                                                                                                                                                                                                                                                                 | The maximum number of lines when `axis` is `vertical`, such as `4`, or a range such as `[2, 4]` for a minimum and a maximum.                                                          |

```svelte
<script lang="ts">
  let email = $state("");
  let bio = $state("");
  let price: number | null = $state(9.99);
</script>

<formview>
  <textfield
    placeholder="Email"
    keyboard="email"
    contenttype="email"
    autocapitalize="never"
    autocorrect={false}
    submitlabel="next"
    value={email}
    oninput={(value) => (email = value)}
  />
  <textfield
    placeholder="Styled placeholder"
    placeholdercolor="red"
    value=""
    oninput={() => {}}
  />
  <textfield
    placeholder="Bio"
    axis="vertical"
    lines={[2, 4]}
    debounce={300}
    value={bio}
    oninput={(value) => (bio = value)}
  />
  <textfield
    format={{ currency: "USD" }}
    value={price}
    oninput={(value: number | null) => (price = value)}
  />
</formview>
```

### `securefield`

A `SecureField`: a text field that hides what the user types, for passwords.

| Attribute          | Type                                                                                                                                                                                                                                                                                                                                                           | Description                                                                                                                             |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `placeholder`      | `string`                                                                                                                                                                                                                                                                                                                                                       | The text shown in the field while it's empty.                                                                                           |
| `placeholdercolor` | `ShapeStyle`                                                                                                                                                                                                                                                                                                                                                   | The color of the placeholder text, such as a named color or a CSS color. Without it, the placeholder uses the system's secondary color. |
| `focused`          | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether the field has keyboard focus. Use `bind:focused` with the `TextField` component to bind it.                                     |
| `keyboard`         | `"default" \| "ascii" \| "numbersAndPunctuation" \| "url" \| "number" \| "phone" \| "namePhone" \| "email" \| "decimal" \| "twitter" \| "webSearch" \| "asciiNumber"`                                                                                                                                                                                          | The keyboard to show, such as `email`, `url`, `number`, `decimal`, or `phone`.                                                          |
| `contenttype`      | `"name" \| "givenName" \| "middleName" \| "familyName" \| "nickname" \| "jobTitle" \| "organization" \| "email" \| "phone" \| "url" \| "username" \| "password" \| "newPassword" \| "oneTimeCode" \| "streetAddress" \| "addressLine1" \| "addressLine2" \| "city" \| "state" \| "postalCode" \| "country" \| "creditCardNumber" \| "location" \| "birthdate"` | What the text is, such as `email`, `username`, `password`, or `oneTimeCode`, so iOS can offer AutoFill and saved passwords.             |
| `autocapitalize`   | `"never" \| "words" \| "sentences" \| "characters"`                                                                                                                                                                                                                                                                                                            | How the text is capitalized: `never`, `words`, `sentences`, or `characters`.                                                            |
| `autocorrect`      | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether autocorrection is on. Set it to `false` to turn it off.                                                                         |
| `submitlabel`      | `"done" \| "go" \| "send" \| "join" \| "route" \| "search" \| "return" \| "next" \| "continue"`                                                                                                                                                                                                                                                                | The label on the Return key, such as `done`, `go`, `next`, `search`, or `send`.                                                         |
| `onsubmit`         | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the user presses Return, after any pending input is sent.                                                                     |
| `onfocus`          | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field gains keyboard focus.                                                                                               |
| `onblur`           | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field loses keyboard focus.                                                                                               |
| `value`            | `string`                                                                                                                                                                                                                                                                                                                                                       | The text in the field. Leave it out to let the field keep whatever the user types.                                                      |
| `debounce`         | `number`                                                                                                                                                                                                                                                                                                                                                       | Milliseconds to wait after the user stops typing before `oninput` runs. Defaults to 0, which runs it on every keystroke.                |
| `oninput`          | `(value: string) => void`                                                                                                                                                                                                                                                                                                                                      | Runs with the new text on each keystroke, or after the `debounce` delay.                                                                |
| `variant`          | `FieldVariant`                                                                                                                                                                                                                                                                                                                                                 | The look of the field: `automatic`, `plain`, or `roundedBorder`.                                                                        |

```svelte
<script lang="ts">
  let password = $state("");
</script>

<formview>
  <securefield
    placeholder="Password"
    contenttype="newPassword"
    value={password}
    oninput={(value) => (password = value)}
  />
  <txt font="caption" color={password.length >= 8 ? "green" : "secondary"}>
    At least 8 characters
  </txt>
</formview>
```

### `texteditor`

A `TextEditor`: an editable area for many lines of text that scrolls. Give it a `height`.

| Attribute                 | Type                                                                                                                                                                                                                                                                                                                                                           | Description                                                                                                                                       |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `placeholdercolor`        | `ShapeStyle`                                                                                                                                                                                                                                                                                                                                                   | The color of the placeholder text, such as a named color or a CSS color. Without it, the placeholder uses the system's secondary color.           |
| `focused`                 | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether the field has keyboard focus. Use `bind:focused` with the `TextField` component to bind it.                                               |
| `keyboard`                | `"default" \| "ascii" \| "numbersAndPunctuation" \| "url" \| "number" \| "phone" \| "namePhone" \| "email" \| "decimal" \| "twitter" \| "webSearch" \| "asciiNumber"`                                                                                                                                                                                          | The keyboard to show, such as `email`, `url`, `number`, `decimal`, or `phone`.                                                                    |
| `contenttype`             | `"name" \| "givenName" \| "middleName" \| "familyName" \| "nickname" \| "jobTitle" \| "organization" \| "email" \| "phone" \| "url" \| "username" \| "password" \| "newPassword" \| "oneTimeCode" \| "streetAddress" \| "addressLine1" \| "addressLine2" \| "city" \| "state" \| "postalCode" \| "country" \| "creditCardNumber" \| "location" \| "birthdate"` | What the text is, such as `email`, `username`, `password`, or `oneTimeCode`, so iOS can offer AutoFill and saved passwords.                       |
| `autocapitalize`          | `"never" \| "words" \| "sentences" \| "characters"`                                                                                                                                                                                                                                                                                                            | How the text is capitalized: `never`, `words`, `sentences`, or `characters`.                                                                      |
| `autocorrect`             | `boolean`                                                                                                                                                                                                                                                                                                                                                      | Whether autocorrection is on. Set it to `false` to turn it off.                                                                                   |
| `submitlabel`             | `"done" \| "go" \| "send" \| "join" \| "route" \| "search" \| "return" \| "next" \| "continue"`                                                                                                                                                                                                                                                                | The label on the Return key, such as `done`, `go`, `next`, `search`, or `send`.                                                                   |
| `onsubmit`                | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the user presses Return, after any pending input is sent.                                                                               |
| `onfocus`                 | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field gains keyboard focus.                                                                                                         |
| `onblur`                  | `() => void`                                                                                                                                                                                                                                                                                                                                                   | Runs when the field loses keyboard focus.                                                                                                         |
| `value`                   | `string`                                                                                                                                                                                                                                                                                                                                                       | The text in the field. Leave it out to let the field keep whatever the user types.                                                                |
| `debounce`                | `number`                                                                                                                                                                                                                                                                                                                                                       | Milliseconds to wait after the user stops typing before `oninput` runs. Defaults to 0, which runs it on every keystroke.                          |
| `oninput`                 | `(value: string) => void`                                                                                                                                                                                                                                                                                                                                      | Runs with the new text on each keystroke, or after the `debounce` delay.                                                                          |
| `scrollcontentbackground` | `"hidden" \| "visible"`                                                                                                                                                                                                                                                                                                                                        | `hidden` removes the editor's system background so the element's own background shows through, like SwiftUI's `scrollContentBackground(.hidden)`. |

```svelte
<script lang="ts">
  let notes = $state("");
</script>

<formview>
  <sectionview header="Notes" footer="{notes.length} characters">
    <texteditor
      value={notes}
      debounce={200}
      oninput={(value) => (notes = value)}
      height={160}
    />
  </sectionview>
</formview>
```

## Pickers

### `picker`

A `Picker`: lets the user choose one option, or several with `multiple`, from its `choice` children.

| Attribute  | Type                                                                                | Description                                                                                                                                                                                                                                                         |
| ---------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `multiple` | `false \| true`                                                                     | Leave it out, or set it to `false`, to let the user choose one option. Set it to `true` to let the user choose several options.                                                                                                                                     |
| `label`    | `string`                                                                            | The label of the picker, shown next to the picked value. Use a `label` child for a custom label. The label of the picker, shown next to the picked values. Use a `label` child for a custom label.                                                                  |
| `value`    | `string \| number \| Array<string \| number>`                                       | The `value` of the selected `choice`. The `value`s of the selected `choice`s, in the order of the choices.                                                                                                                                                          |
| `variant`  | `"automatic" \| "menu" \| "segmented" \| "wheel" \| "inline" \| "navigation"`       | The picker style: `automatic`, `menu`, `segmented`, `wheel`, `inline`, or `navigation`. `navigation` opens the options on their own screen, so the picker needs to be inside a `navstack`. The picker style for several options: `inline`, `menu`, or `navigation`. |
| `onchange` | `((value: string \| number) => void) \| ((value: Array<string \| number>) => void)` | Runs when the user picks an option, with the option's `value`. Runs when the selection changes, with the new array of values.                                                                                                                                       |

```svelte
<script lang="ts">
  let flavor = $state<string | number>("vanilla");
  let toppings = $state<Array<string | number>>(["sprinkles"]);
</script>

<formview>
  <picker label="Flavor" value={flavor} onchange={(value) => (flavor = value)}>
    <choice value="vanilla">Vanilla</choice>
    <choice value="chocolate">Chocolate</choice>
    <choice value="strawberry">Strawberry</choice>
  </picker>
  <picker
    label="Toppings"
    multiple
    variant="inline"
    value={toppings}
    onchange={(value) => (toppings = value)}
  >
    <choice value="sprinkles">Sprinkles</choice>
    <choice value="nuts">Nuts</choice>
  </picker>
</formview>
```

### `choice`

One option of a `picker`: its text is the title, and its `value` is what the picker's `onchange` receives.

| Attribute | Type               | Description                                                                 |
| --------- | ------------------ | --------------------------------------------------------------------------- |
| `value`   | `string \| number` | The value that the picker's `onchange` receives when this option is picked. |
| `symbol`  | `string`           | The SF Symbol shown beside the option's title.                              |

This element doesn't take modifiers.

```svelte
<script lang="ts">
  let layout = $state<string | number>("list");
</script>

<picker
  value={layout}
  variant="segmented"
  padding
  onchange={(value) => (layout = value)}
>
  <choice value="list" symbol="list.bullet">List</choice>
  <choice value="grid" symbol="square.grid.2x2">Grid</choice>
</picker>
```

### `datepicker`

A `DatePicker`: lets the user pick a date, a time, or both.

| Attribute    | Type                                                 | Description                                                                        |
| ------------ | ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `value`      | `Date \| string`                                     | The date to show, as a `Date` or an ISO 8601 string.                               |
| `min`        | `Date \| string`                                     | The earliest date the user can pick, as a `Date` or an ISO 8601 string.            |
| `max`        | `Date \| string`                                     | The latest date the user can pick, as a `Date` or an ISO 8601 string.              |
| `components` | `"date" \| "time" \| "datetime"`                     | Which parts the user picks: `date`, `time`, or `datetime`. Defaults to `datetime`. |
| `variant`    | `"automatic" \| "compact" \| "graphical" \| "wheel"` | The picker style: `automatic`, `compact`, `graphical`, or `wheel`.                 |
| `onchange`   | `(value: Date) => void`                              | Runs when the user picks a date, with a `Date`.                                    |

```svelte
<script lang="ts">
  let date = $state(new Date());
</script>

<formview>
  <datepicker
    value={date}
    components="date"
    onchange={(value) => (date = value)}
  >
    <txt>Check-in</txt>
  </datepicker>
  <datepicker
    value={date}
    components="time"
    onchange={(value) => (date = value)}
  >
    <txt>Arrival</txt>
  </datepicker>
  <datepicker
    value={date}
    components="date"
    variant="graphical"
    onchange={(value) => (date = value)}
  />
</formview>
```

### `multidatepicker`

A `MultiDatePicker`: a calendar where the user taps days on and off.

| Attribute  | Type                             | Description                                                                    |
| ---------- | -------------------------------- | ------------------------------------------------------------------------------ |
| `value`    | `Array<string>`                  | The picked days, as `YYYY-MM-DD` strings. These don't depend on the time zone. |
| `min`      | `Date \| string`                 | The earliest day the user can pick, as a `Date` or an ISO 8601 string.         |
| `max`      | `Date \| string`                 | The latest day the user can pick, as a `Date` or an ISO 8601 string.           |
| `onchange` | `(value: Array<string>) => void` | Runs when the user taps a day on or off, with the new array of days.           |

```svelte
<script lang="ts">
  let days: Array<string> = $state([]);
</script>

<formview>
  <multidatepicker value={days} onchange={(value) => (days = value)}>
    <txt>Delivery days</txt>
  </multidatepicker>
  <txt color="secondary">
    {days.length}
    {days.length === 1 ? "day" : "days"} picked
  </txt>
</formview>
```

### `colorpicker`

A `ColorPicker`: lets the user pick a color.

| Attribute         | Type                            | Description                                                                                                                 |
| ----------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `value`           | `string`                        | The starting color, as any color value. Defaults to black.                                                                  |
| `supportsopacity` | `boolean`                       | Whether the user can change the opacity. Defaults to `true`.                                                                |
| `onchange`        | `(value: `#${string}`) => void` | Runs when the user picks a color, with a hex string such as `#FF9500`, or `#FF950080` when the color is partly transparent. |

```svelte
<script lang="ts">
  let color: `#${string}` = $state("#FF9500");
</script>

<formview>
  <colorpicker
    value={color}
    supportsopacity={false}
    onchange={(value) => (color = value)}
  >
    <txt>Highlight</txt>
  </colorpicker>
  <roundedrectangle fill={color} height={44} />
</formview>
```

## Shapes

### `rectangle`

A `Rectangle` shape.

| Attribute      | Type                            | Description                                                                                                                             |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |

```svelte
<rectangle
  fill={{
    linear: ["teal", "blue"],
    start: "topLeading",
    end: "bottomTrailing",
  }}
  width={160}
  height={100}
/>
```

### `roundedrectangle`

A `RoundedRectangle` shape.

| Attribute      | Type                            | Description                                                                                                                             |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |
| `corners`      | `"continuous" \| "circular"`    | The corner style: `continuous` (the default) or `circular`.                                                                             |
| `cornerradius` | `number`                        | The corner radius in points. Defaults to 8.                                                                                             |

```svelte
<roundedrectangle
  cornerradius={16}
  fill="secondarySystemBackground"
  stroke="separator"
  linewidth={2}
  width={160}
  height={100}
/>
```

### `unevenroundedrectangle`

An `UnevenRoundedRectangle` shape, with its own radius for each corner.

| Attribute        | Type                            | Description                                                                                                                             |
| ---------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`           | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`         | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder`   | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`      | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`        | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`       | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`           | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`      | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`       | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |
| `corners`        | `"continuous" \| "circular"`    | The corner style: `continuous` (the default) or `circular`.                                                                             |
| `topleading`     | `number`                        | The radius in points of the top leading corner. Defaults to 0.                                                                          |
| `toptrailing`    | `number`                        | The radius in points of the top trailing corner. Defaults to 0.                                                                         |
| `bottomleading`  | `number`                        | The radius in points of the bottom leading corner. Defaults to 0.                                                                       |
| `bottomtrailing` | `number`                        | The radius in points of the bottom trailing corner. Defaults to 0.                                                                      |

```svelte
<unevenroundedrectangle
  topleading={32}
  bottomtrailing={32}
  fill="purple"
  width={160}
  height={100}
/>
```

### `circleshape`

A `Circle` shape.

| Attribute      | Type                            | Description                                                                                                                             |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |

```svelte
<hstack spacing={16}>
  <circleshape
    stroke="teal"
    linewidth={4}
    linecap="round"
    dash={[8, 6]}
    width={100}
    height={100}
  />
  <circleshape strokeborder="teal" linewidth={4} width={100} height={100} />
</hstack>
```

### `ellipseshape`

An `Ellipse` shape.

| Attribute      | Type                            | Description                                                                                                                             |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |

```svelte
<ellipseshape fill="orange.gradient" width={160} height={90} />
```

### `capsule`

A `Capsule` shape, with fully rounded ends.

| Attribute      | Type                            | Description                                                                                                                             |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                           |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                         |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`. |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                      |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                          |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                       |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                          |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                     |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                          |
| `corners`      | `"continuous" \| "circular"`    | The corner style: `continuous` (the default) or `circular`.                                                                             |

```svelte
<capsule fill="green" width={160} height={44}>
  <overlay>
    <txt color="white" weight="semibold">Capsule</txt>
  </overlay>
</capsule>
```

### `pathshape`

A `Path` shape drawn from SVG path data.

| Attribute      | Type                            | Description                                                                                                                              |
| -------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `fill`         | `ShapeStyle`                    | The fill style of the shape. Without `fill` or `stroke`, the shape uses the foreground style.                                            |
| `stroke`       | `ShapeStyle`                    | The style of the shape's outline, centered on the shape's edge.                                                                          |
| `strokeborder` | `ShapeStyle`                    | The style of the shape's outline, drawn inside the shape's edge, so the outline stays within the frame. Takes precedence over `stroke`.  |
| `linewidth`    | `number`                        | The width of the outline in points. Defaults to 1.                                                                                       |
| `linecap`      | `"butt" \| "round" \| "square"` | The shape of the outline's ends: `butt`, `round`, or `square`.                                                                           |
| `linejoin`     | `"miter" \| "round" \| "bevel"` | The shape of the outline's corners: `miter`, `round`, or `bevel`.                                                                        |
| `dash`         | `Array<number>`                 | The lengths in points of the dashes and gaps in the outline, such as `[5, 3]`.                                                           |
| `dashphase`    | `number`                        | The offset in points into the dash pattern where the outline starts. Defaults to 0.                                                      |
| `fillrule`     | `"nonzero" \| "evenodd"`        | How the fill decides which areas are inside the shape: `nonzero` or `evenodd`.                                                           |
| `d`            | `string`                        | SVG path data for the shape. Every path command is supported, including arcs.                                                            |
| `viewbox`      | `string`                        | The SVG `viewBox`, such as `0 0 24 24`. With it, the path scales to fit the frame. Without it, the path is drawn at its own coordinates. |

```svelte
<pathshape
  d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"
  viewbox="0 0 24 24"
  fill="yellow"
  stroke="orange"
  linejoin="round"
  width={100}
  height={100}
/>
```

## Layers and Liquid Glass

### `background`

The background of its parent element, drawn behind the parent at its size. The parent's opacity and transforms apply to it too, but its clip shape, border, and shadow don't.

| Attribute   | Type             | Description                                                                                     |
| ----------- | ---------------- | ----------------------------------------------------------------------------------------------- |
| `alignment` | `LayerAlignment` | Where the background sits, such as `center` (the default) or a corner such as `bottomTrailing`. |

This element doesn't take modifiers.

```svelte
<vstack padding={24}>
  <txt font="title2" weight="bold" color="white">Background</txt>
  <background>
    <roundedrectangle
      fill={{ linear: ["pink", "orange"], start: "leading", end: "trailing" }}
      cornerradius={16}
    />
  </background>
</vstack>
```

### `overlay`

The overlay of its parent element, drawn in front of the parent at its size. The parent's opacity and transforms apply to it too, but its clip shape, border, and shadow don't.

| Attribute   | Type             | Description                                                                                  |
| ----------- | ---------------- | -------------------------------------------------------------------------------------------- |
| `alignment` | `LayerAlignment` | Where the overlay sits, such as `center` (the default) or a corner such as `bottomTrailing`. |

This element doesn't take modifiers.

```svelte
<imageview
  name="Logo"
  fit="fit"
  width={96}
  height={96}
  label="swiftui-svelte logo"
>
  <overlay alignment="topTrailing">
    <txt
      font="caption"
      weight="bold"
      color="white"
      padding={{ horizontal: 6, vertical: 2 }}
      background="red"
      clipshape="capsule">3</txt
    >
  </overlay>
</imageview>
```

### `maskview`

The mask of its parent element: the parent is masked by this element's content.

| Attribute   | Type             | Description                                                               |
| ----------- | ---------------- | ------------------------------------------------------------------------- |
| `alignment` | `LayerAlignment` | Where the mask sits relative to the parent, such as `center` or `bottom`. |

This element doesn't take modifiers.

```svelte
<rectangle
  fill={{ linear: ["red", "purple"], start: "top", end: "bottom" }}
  width={120}
  height={120}
>
  <maskview>
    <sfsymbol name="heart.fill" size={110} />
  </maskview>
</rectangle>
```

### `glasseffectcontainer`

A `GlassEffectContainer`: renders the Liquid Glass of its children together on iOS 26 and later.

| Attribute | Type     | Description                                                         |
| --------- | -------- | ------------------------------------------------------------------- |
| `spacing` | `number` | The distance in points at which nearby glass shapes blend into one. |

```svelte
<zstack
  padding={32}
  background={{
    linear: ["teal", "indigo"],
    start: "topLeading",
    end: "bottomTrailing",
  }}
  radius={24}
>
  <glasseffectcontainer spacing={24}>
    <hstack spacing={24}>
      <sfsymbol
        name="scribble.variable"
        font="title"
        width={64}
        height={64}
        glasseffect
      />
      <sfsymbol
        name="eraser.fill"
        font="title"
        width={64}
        height={64}
        glasseffect
      />
      <sfsymbol
        name="paintbrush.fill"
        font="title"
        width={64}
        height={64}
        glasseffect
      />
    </hstack>
  </glasseffectcontainer>
</zstack>
```

## Modifiers

Every element takes these attributes, except the few whose entries say they don't. They're grouped by what they do, and each group ends with an example.

### Typography

| Attribute       | Type                                                | Description                                                                                                                                                                                                                        |
| --------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `font`          | `Font`                                              | The text style, which follows Dynamic Type, such as `headline` or `caption`. Applies to all the text inside the element.                                                                                                           |
| `fontname`      | `string`                                            | The PostScript name of a font to use instead of a system font, such as `Georgia-Bold`. With `size`, the font has that fixed size. With `font`, the size scales with Dynamic Type relative to that text style.                      |
| `fontfallbacks` | `Array<string>`                                     | PostScript names of fonts to try, in order, for characters that `fontname` doesn't have, such as an Arabic font for Arabic text. Each fallback is used when the font before it lacks the character.                                |
| `size`          | `number`                                            | A font size in points. Without `fontname`, it's a fixed size, like `.system(size:)`, and it doesn't follow Dynamic Type. With `fontname` and `font`, it's the base size that scales with Dynamic Type relative to that text style. |
| `design`        | `"default" \| "rounded" \| "serif" \| "monospaced"` | The font design: `default`, `rounded`, `serif`, or `monospaced`.                                                                                                                                                                   |
| `weight`        | `Weight`                                            | The font weight, from `ultraLight` through `black`.                                                                                                                                                                                |
| `italic`        | `boolean`                                           | Draws the text in italics.                                                                                                                                                                                                         |

```svelte
<vstack alignment="leading" spacing={8} padding>
  <txt font="largeTitle">Large title</txt>
  <txt font="headline" weight="black">Black headline</txt>
  <txt size={28} design="rounded">Rounded at 28 points</txt>
  <txt font="callout" design="monospaced">let monospaced = true</txt>
  <txt design="serif" weight="light">Light serif</txt>
  <txt fontname="Georgia-Bold" size={24}>Georgia Bold at 24 points</txt>
  <txt fontname="Georgia" font="body" italic
    >Georgia italic, scaled with Dynamic Type</txt
  >
  <txt fontname="Georgia" size={24} weight="bold"
    >Georgia family, weight bold</txt
  >
  <txt fontname="Georgia" size={20} fontfallbacks={["GeezaPro"]}
    >Georgia with a fallback: مرحبا</txt
  >
</vstack>
```

### Color and style

| Attribute          | Type                                                                                      | Description                                                                                                                                                                                                                                                                                              |
| ------------------ | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `color`            | `ShapeStyle`                                                                              | The foreground style of the content, such as a named color, a CSS color, or a gradient.                                                                                                                                                                                                                  |
| `tint`             | `Color`                                                                                   | The tint of the controls inside the element. Takes a color only.                                                                                                                                                                                                                                         |
| `background`       | `ShapeStyle`                                                                              | The background style, such as a color, a material, or a gradient, drawn behind the element.                                                                                                                                                                                                              |
| `opacity`          | `number`                                                                                  | The opacity of the element, from 0 (transparent) to 1 (opaque). Defaults to 1.                                                                                                                                                                                                                           |
| `brightness`       | `number`                                                                                  | Adds brightness to the element, from -1 (darker) to 1 (brighter). Defaults to 0, which leaves the element unchanged.                                                                                                                                                                                     |
| `colormultiply`    | `Color`                                                                                   | Multiplies the colors of the element by this color, which darkens or tints the element. Takes a color only.                                                                                                                                                                                              |
| `blendmode`        | `BlendMode`                                                                               | How the element's colors blend with the views behind it, such as `multiply` or `screen`. Defaults to `normal`.                                                                                                                                                                                           |
| `compositinggroup` | `boolean`                                                                                 | Draws the element and its children as one layer before blending, so `opacity` and `blendmode` apply to the group as a whole.                                                                                                                                                                             |
| `lighten`          | `number`                                                                                  | Brightens the element by blending a copy of it over itself with the plus-lighter mode at this opacity, from 0 to 1. Unlike brightness, which adds the same amount to every color, the copy's opacity sets the strength, so 0.125 adds an eighth of the element's color again.                            |
| `insetshadow`      | `boolean`                                                                                 | Draws a soft inner edge along the element's `clipshape`, or along the rounded corners set by `radius` when there is no `clipshape`, like an inset shadow. Combine it with `opacity` and `pressed`, such as `opacity={0}` with `pressed={{ opacity: 1 }}`, to fade the edge in while a button is pressed. |
| `border`           | `Color \| { color?: ShapeStyle; width?: number; }`                                        | Draws a border in a color, or as `{ color, width }`, where `width` is in points and defaults to 1.                                                                                                                                                                                                       |
| `ring`             | `{ width: number; color?: ShapeStyle; }`                                                  | Draws a ring around the element, outside its bounds, in `color` (the current color by default) with the given `width` in points. The ring takes no space in the layout, as a CSS ring doesn't. The ring-* classes set this.                                                                              |
| `shadow`           | `false \| number \| Color \| { color?: Color; radius?: number; x?: number; y?: number; }` | Draws a shadow. A number sets the blur radius, and an object sets the `color`, `radius`, `x`, and `y` of the shadow in points. `false` draws no shadow, which removes the shadow that a button's label has.                                                                                              |
| `blur`             | `number`                                                                                  | Blurs the element by this radius in points.                                                                                                                                                                                                                                                              |
| `radius`           | `number`                                                                                  | Rounds the corners of the element to this radius in points.                                                                                                                                                                                                                                              |
| `cornerstyle`      | `"continuous" \| "circular"`                                                              | The style of the corners that `radius` rounds: `"continuous"` (the default, Apple's smooth squircle curve) or `"circular"` (quarter-circle arcs).                                                                                                                                                        |
| `controlsize`      | `"mini" \| "small" \| "regular" \| "large" \| "extraLarge"`                               | The size of the controls inside the element: `mini`, `small`, `regular`, `large`, or `extraLarge`.                                                                                                                                                                                                       |

```svelte
<vstack spacing={16} padding>
  <txt
    font="title"
    weight="bold"
    color={{ linear: ["pink", "purple"], start: "leading", end: "trailing" }}
  >
    Gradient text
  </txt>
  <txt
    padding
    background="yellow"
    radius={8}
    border={{ color: "orange", width: 2 }}>Bordered</txt
  >
  <txt
    padding
    background="systemBackground"
    radius={12}
    shadow={{ color: "#00000033", radius: 8, y: 4 }}>Shadow</txt
  >
  <hstack spacing={16}>
    <txt padding background="yellow" radius={16} cornerstyle="continuous"
      >Continuous</txt
    >
    <txt padding background="yellow" radius={16} cornerstyle="circular"
      >Circular</txt
    >
  </hstack>
  <hstack spacing={16}>
    <txt opacity={0.4}>Faded</txt>
    <txt blur={2}>Blurred</txt>
  </hstack>
  <hstack spacing={16}>
    <txt padding background="orange" radius={8} brightness={0.3}>Brighter</txt>
    <txt padding background="orange" radius={8} lighten={0.125}>Lightened</txt>
    <txt padding background="orange" radius={8} colormultiply="blue">Tinted</txt
    >
    <txt padding background="white" radius={8} blendmode="multiply" color="red"
      >Multiplied</txt
    >
  </hstack>
  <hstack
    spacing={16}
    padding
    background="white"
    radius={12}
    hovered={{ lighten: 0.125 }}
  >
    <txt>Lightened on hover</txt>
    <rectangle background="clear" radius={12} insetshadow />
  </hstack>
  <txt ring={{ width: 2, color: "orange" }} radius={8} padding={8}>Ringed</txt>
  <txt compositinggroup opacity={0.5}>
    <span color="red">Grouped</span> <span color="blue">spans</span>
  </txt>
  <btn variant="prominent" tint="green" controlsize="large">
    Large green button
  </btn>
</vstack>
```

### Frame and layout

| Attribute         | Type                                    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `padding`         | `Insets`                                | Pads the element. A number pads every edge by that many points, an object such as `{ horizontal: 20, top: 4 }` pads each edge separately, and a bare `padding` adds 16 points. A negative value works as it does in SwiftUI: the element's frame shrinks by that much, and content that fills the space it's offered, such as a shape, draws that far past the frame. Use it for shadows and backgrounds that spread beyond their element. |
| `width`           | `number`                                | A fixed width in points.                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `height`          | `number`                                | A fixed height in points.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `linebox`         | `number`                                | The height in points of one line of text, as CSS `line-height` sets it on the web. Text that fits on one line gets exactly this height, centered in it, and text that wraps gets its own height, or this one if that's taller. Within a point of its ideal width, the text keeps its ideal width, so that pixel rounding at fractional font sizes doesn't push its last letter onto a second line.                                         |
| `minwidth`        | `Length`                                | The minimum width in points, or `infinity` to fill the available width.                                                                                                                                                                                                                                                                                                                                                                    |
| `idealwidth`      | `Length`                                | The ideal width in points, or `infinity`, used as the preferred size in a flexible frame.                                                                                                                                                                                                                                                                                                                                                  |
| `maxwidth`        | `Length`                                | The maximum width in points, or `infinity` to grow to fill the available width.                                                                                                                                                                                                                                                                                                                                                            |
| `minheight`       | `Length`                                | The minimum height in points, or `infinity` to fill the available height.                                                                                                                                                                                                                                                                                                                                                                  |
| `idealheight`     | `Length`                                | The ideal height in points, or `infinity`, used as the preferred size in a flexible frame.                                                                                                                                                                                                                                                                                                                                                 |
| `maxheight`       | `Length`                                | The maximum height in points, or `infinity` to grow to fill the available height.                                                                                                                                                                                                                                                                                                                                                          |
| `fixedsize`       | `boolean \| "horizontal" \| "vertical"` | Keeps the element at its ideal size instead of letting its parent shrink it: `true` for both axes, or `horizontal` or `vertical`.                                                                                                                                                                                                                                                                                                          |
| `layoutpriority`  | `number`                                | The priority the element has when its parent doesn't have room for every child. Higher values keep their size first.                                                                                                                                                                                                                                                                                                                       |
| `framealignment`  | `LayerAlignment`                        | Where the content sits inside a flexible frame, such as `center` or `topLeading`.                                                                                                                                                                                                                                                                                                                                                          |
| `aspectratio`     | `number`                                | The ratio of width to height that the element keeps.                                                                                                                                                                                                                                                                                                                                                                                       |
| `contentmode`     | `"fit" \| "fill"`                       | Fits the element inside its space (`fit`), or fills the space (`fill`), keeping the aspect ratio.                                                                                                                                                                                                                                                                                                                                          |
| `ignoressafearea` | `SafeAreaIgnoring`                      | Lets the element extend under the safe area: `true` for every edge, `keyboard` or `container` for only that region, an edge, an array of edges, or `{ regions, edges }`.                                                                                                                                                                                                                                                                   |
| `zindex`          | `number`                                | The stacking order of the element among its siblings. Higher values draw in front.                                                                                                                                                                                                                                                                                                                                                         |
| `hidden`          | `boolean`                               | Hides the element but keeps its space in the layout.                                                                                                                                                                                                                                                                                                                                                                                       |

```svelte
<script lang="ts">
  let hidden = $state(false);
</script>

<zstack>
  <rectangle fill="secondarySystemBackground" ignoressafearea />
  <vstack spacing={12} padding={{ horizontal: 20, vertical: 12 }}>
    <txt width={200} height={44} background="mint">200 by 44 points</txt>
    <txt linebox={32} background="yellow">One line, 32 points tall</txt>
    <txt fixedsize layoutpriority={1} background="green"
      >Keeps its ideal size</txt
    >
    <txt
      maxwidth="infinity"
      framealignment="leading"
      padding={8}
      background="teal">Fills the width</txt
    >
    <txt
      minwidth={80}
      idealwidth={160}
      maxwidth={240}
      minheight={32}
      idealheight={44}
      maxheight={60}
      background="cyan">Flexible frame</txt
    >
    <roundedrectangle
      fill="indigo"
      aspectratio={16 / 9}
      contentmode="fit"
      maxwidth={200}
    />
    <zstack>
      <circleshape
        fill="red"
        width={60}
        height={60}
        offset={{ x: -15 }}
        zindex={1}
      />
      <circleshape fill="blue" width={60} height={60} offset={{ x: 15 }} />
    </zstack>
    <hstack>
      <toggle checked={hidden} onchange={(next) => (hidden = next)}>
        Hide the badge
      </toggle>
      <txt
        {hidden}
        color="white"
        background="red"
        padding={{ horizontal: 8, vertical: 2 }}
        clipshape="capsule">Badge</txt
      >
    </hstack>
  </vstack>
</zstack>
```

### Transforms and shapes

| Attribute        | Type              | Description                                                                                                                                                            |
| ---------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `offset`         | `Point`           | Moves the element by `{ x, y }` points without changing the layout around it.                                                                                          |
| `position`       | `Point`           | Places the element's center at `{ x, y }` points in its parent's coordinate space.                                                                                     |
| `rotation`       | `number`          | Rotates the element by a number of degrees around `rotationanchor`.                                                                                                    |
| `rotationanchor` | `UnitPointName`   | The point the element rotates around, as a unit point such as `center` or `topLeading`. Defaults to `center`.                                                          |
| `scale`          | `number \| Point` | Scales the element by a number, or by `{ x, y }` for each axis, around `scaleanchor`.                                                                                  |
| `scaleanchor`    | `UnitPointName`   | The point the element scales around, as a unit point such as `center`. Defaults to `center`.                                                                           |
| `clipshape`      | `ClipShape`       | Clips the element to a shape: `rectangle`, `circle`, `capsule`, `ellipse`, a corner radius in points, an object with corner radii, or an SVG path as `{ d, viewbox }`. |
| `contentshape`   | `ClipShape`       | The shape that responds to taps, using the same values as `clipshape`.                                                                                                 |

```svelte
<script lang="ts">
  let taps = $state(0);
</script>

<vstack spacing={32} padding>
  <hstack spacing={32}>
    <roundedrectangle fill="orange" width={60} height={60} rotation={30} />
    <roundedrectangle
      fill="pink"
      width={60}
      height={60}
      rotation={-15}
      rotationanchor="bottomLeading"
    />
    <roundedrectangle
      fill="purple"
      width={60}
      height={60}
      scale={{ x: 1.2, y: 0.8 }}
      scaleanchor="bottom"
    />
  </hstack>
  <zstack width={200} height={80} background="quaternarySystemFill" radius={12}>
    <circleshape
      fill="teal"
      width={24}
      height={24}
      position={{ x: 40, y: 40 }}
    />
    <circleshape fill="teal" width={24} height={24} offset={{ x: 40 }} />
  </zstack>
  <imageview
    name="Logo"
    fit="fill"
    width={80}
    height={80}
    clipshape="circle"
    label="swiftui-svelte logo"
  />
  <hstack padding contentshape="rectangle" ontap={() => taps++}>
    <txt>Tap anywhere in this row</txt>
    <spacer />
    <txt>{taps}</txt>
  </hstack>
</vstack>
```

### Animation and transitions

| Attribute            | Type               | Description                                                                                                                                                                                                                            |
| -------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `animated`           | `boolean`          | Animates the element's children as they're added, removed, or reordered, using the curve from `animation`.                                                                                                                             |
| `animation`          | `AnimationOptions` | The animation curve for `animated` and `transition`: a curve name, or an object with `type`, `duration`, `delay`, `bounce`, `speed`, `repeat`, and `autoreverses`. `true` uses the default curve, and `false` turns the animation off. |
| `disablesanimations` | `boolean`          | Turns off animations for the element and everything inside it, so its changes happen at once.                                                                                                                                          |
| `namespace`          | `boolean`          | Starts a namespace for the `matchedid` elements inside this element. Elements with the same `matchedid` animate from one position to the other when one replaces the other.                                                            |
| `matchedid`          | `string`           | Matches this element with the element that has the same `matchedid` in the same namespace, so the two animate between their positions when one replaces the other.                                                                     |
| `transition`         | `Transition`       | The transition that plays when the element is added and removed, such as `scale opacity` or `move-top`.                                                                                                                                |
| `in`                 | `Transition`       | The transition that plays only when the element is added.                                                                                                                                                                              |
| `out`                | `Transition`       | The transition that plays only when the element is removed.                                                                                                                                                                            |

```svelte
<script lang="ts">
  import { withAnimation } from "swiftui-svelte";

  const items = $state([1, 2, 3]);
  let saved = $state(false);
  let shifted = $state(false);
  let next = 4;
</script>

<vstack spacing={16} padding>
  <hstack spacing={8} animated animation="snappy">
    {#each items as item (item)}
      <txt
        width={40}
        height={40}
        color="white"
        background="blue"
        radius={8}
        transition="scale opacity">{item}</txt
      >
    {/each}
  </hstack>
  <hstack>
    <btn variant="bordered" onclick={() => items.push(next++)}>Add</btn>
    <btn variant="bordered" onclick={() => items.shift()}>Remove</btn>
  </hstack>
  <btn
    variant="prominent"
    onclick={() => withAnimation(() => (saved = !saved), "bouncy")}
  >
    Save
  </btn>
  <btn
    variant="bordered"
    onclick={() =>
      withAnimation(() => (shifted = !shifted), {
        type: "timingCurve",
        curve: [0.4, 0, 0.2, 1],
        duration: 400,
      })}
  >
    Curved
  </btn>
  <hstack spacing={16}>
    <txt
      width={96}
      height={40}
      color="white"
      background="teal"
      radius={8}
      offset={{ x: shifted ? 120 : 0 }}>Curved</txt
    >
    <txt
      disablesanimations
      width={96}
      height={40}
      color="white"
      background="orange"
      radius={8}
      offset={{ x: shifted ? 120 : 0 }}>Instant</txt
    >
  </hstack>
  <vstack spacing={12} namespace>
    {#if shifted}
      <txt
        matchedid="badge"
        font="title"
        color="white"
        background="purple"
        radius={16}
        padding={16}>Badge</txt
      >
    {:else}
      <txt
        matchedid="badge"
        font="caption"
        color="white"
        background="purple"
        radius={8}
        padding={4}>Badge</txt
      >
    {/if}
  </vstack>
  {#if saved}
    <txt
      in="move-top"
      out="opacity"
      animation={{ type: "spring", bounce: 0.4 }}
    >
      Saved!
    </txt>
  {/if}
</vstack>
```

### Gestures

| Attribute             | Type                                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| --------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ontap`               | `(location: GesturePoint) => void`       | Runs when the element is tapped, with the tap's `{ x, y }` position in the element's coordinates.                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `tapcount`            | `number`                                 | The number of taps that trigger `ontap`. Defaults to 1, so 2 means a double tap.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `onlongpress`         | `() => void`                             | Runs when the user holds a finger down on the element for `longpressduration` milliseconds.                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `longpressduration`   | `number`                                 | How long the user must hold a finger down, in milliseconds, before `onlongpress` runs. Defaults to 500.                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `ondrag`              | `(drag: DragEvent) => void`              | Runs as the user drags the element, with the drag's phase, position, and velocity.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `dragdistance`        | `number`                                 | The distance in points the finger must move before a drag starts. Defaults to 10.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `onmagnify`           | `(magnify: MagnifyEvent) => void`        | Runs during a pinch gesture, with the pinch's phase, magnification, and velocity.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `onrotate`            | `(rotate: RotateEvent) => void`          | Runs during a two-finger rotation, with the rotation's phase, angle, and velocity.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `onhover`             | `(event: HoverEvent) => void`            | Runs as the pointer moves over the element: `enter` when it arrives, `move` as it moves, and `exit` when it leaves. `location` is the pointer's `{ x, y }` in points, and it's missing on `exit`.                                                                                                                                                                                                                                                                                                                                                      |
| `onscrollvisibility`  | `(event: { visible: boolean; }) => void` | Runs when the element scrolls into or out of view in its `scrollview` or `list`, with `visible`.                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `visibilitythreshold` | `number`                                 | The share of the element that must be on screen to count as visible, from 0 to 1. Defaults to 0, which counts any part of the element.                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `allowshittesting`    | `boolean`                                | Whether the element responds to touches and the pointer. Set it to `false` to let touches pass through it to the views behind.                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `pressed`             | `ButtonFeedback`                         | The look of this element while the `btn` around it is pressed. Any modifier here overrides the same attribute on this element while the press lasts, such as `background`, `radius`, `border`, `shadow`, `colormultiply`, `scale`, `opacity`, `brightness`, or `color`. Set a value to `false` to remove it, such as `shadow: false`. `animation` sets how the change is animated, both when the press starts and when it ends. On a `btn`, the same overrides apply to the label's direct children, and a child's own `pressed` value wins over them. |
| `hovered`             | `ButtonFeedback`                         | The look of this element while the pointer is over the `btn` around it. It takes the same values as `pressed`, and `pressed` wins while both apply.                                                                                                                                                                                                                                                                                                                                                                                                    |

```svelte
<script lang="ts">
  let last = $state("Try a gesture");
  let drag = $state({ x: 0, y: 0 });
  let zoom = $state(1);
  let angle = $state(0);
  let hovered = $state("Move the pointer over the box");
  let shown = $state(0);
</script>

<vstack spacing={20} padding>
  <txt font="headline">{last}</txt>
  <zstack>
    <txt
      padding
      background="yellow"
      radius={8}
      ontap={() => (last = "Under the cover")}>Tap under the cover</txt
    >
    <rectangle
      fill="red"
      width={180}
      height={44}
      radius={8}
      opacity={0.3}
      allowshittesting={false}
      ontap={() => (last = "Cover")}
    />
  </zstack>
  <txt
    padding
    width={240}
    background="quaternarySystemFill"
    radius={8}
    onhover={(event) =>
      (hovered =
        event.phase === "exit"
          ? "Left the box"
          : `${event.phase} at ${Math.round(event.location?.x ?? 0)}, ${Math.round(event.location?.y ?? 0)}`)}
    >{hovered}</txt
  >
  <hstack spacing={12}>
    <txt
      padding
      background="yellow"
      radius={8}
      tapcount={2}
      ontap={() => (last = "Double tap")}>Double-tap me</txt
    >
    <txt
      padding
      background="orange"
      radius={8}
      longpressduration={1000}
      onlongpress={() => (last = "Long press")}>Hold me</txt
    >
  </hstack>
  <zstack
    width={240}
    height={120}
    background="quaternarySystemFill"
    radius={16}
    dragdistance={0}
    ondrag={(event) =>
      (drag = event.phase === "ended" ? { x: 0, y: 0 } : event.translation)}
  >
    <circleshape fill="blue" width={48} height={48} offset={drag} />
  </zstack>
  <zstack
    width={240}
    height={160}
    background="quaternarySystemFill"
    radius={16}
    onmagnify={(event) =>
      (zoom = event.phase === "ended" ? 1 : event.magnification)}
    onrotate={(event) => (angle = event.phase === "ended" ? 0 : event.degrees)}
  >
    <roundedrectangle
      fill="green"
      width={80}
      height={80}
      scale={zoom}
      rotation={angle}
    />
  </zstack>
  <scrollview axes="horizontal" height={56} indicators={false}>
    <hstack spacing={8} padding>
      {#each Array.from({ length: 12 }, (_, index) => index + 1) as item (item)}
        <txt
          padding
          background="blue"
          color="white"
          radius={8}
          visibilitythreshold={0.5}
          onscrollvisibility={(event) => {
            shown = event.visible ? item : shown;
          }}>{item}</txt
        >
      {/each}
    </hstack>
  </scrollview>
  <txt font="caption" color="secondary">Last chip seen: {shown}</txt>
  <btn pressed={{ scale: 0.95 }} hovered={{ opacity: 0.8 }}>
    <txt
      padding
      background="blue"
      color="white"
      radius={8}
      pressed={{ color: "yellow" }}
    >
      Press or hover
    </txt>
  </btn>
</vstack>
```

### Appearing, tasks, and size

| Attribute     | Type                                  | Description                                                                                                                                       |
| ------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `onappear`    | `() => void`                          | Runs when SwiftUI shows the element, such as when a list row scrolls into view.                                                                   |
| `ondisappear` | `() => void`                          | Runs when SwiftUI hides the element.                                                                                                              |
| `ontask`      | `(signal: AbortSignal) => unknown`    | Runs when the element appears, like SwiftUI's `.task`. The `AbortSignal` it receives aborts when the element disappears or when `taskid` changes. |
| `taskid`      | `string \| number \| boolean \| null` | Runs `ontask` again whenever this value changes. The previous run is canceled first.                                                              |
| `onresize`    | `(size: Size) => void`                | Runs with the element's `{ width, height }` in points when it first appears and whenever its size changes.                                        |

```svelte
<script lang="ts">
  const rows = Array.from({ length: 40 }, (_, index) => index + 1);
  let width = $state(0);
  let city = $state<string | number>("Paris");
  let status = $state("");
  let visible = $state(0);

  async function load(signal: AbortSignal) {
    status = "Loading…";
    await new Promise((resolve) => setTimeout(resolve, 500));
    if (!signal.aborted) status = `Loaded the weather for ${city}`;
  }
</script>

<vstack
  spacing={16}
  padding
  onresize={(size) => (width = Math.round(size.width))}
>
  <txt>This stack is {width} points wide.</txt>
  <picker value={city} variant="segmented" onchange={(value) => (city = value)}>
    <choice value="Paris">Paris</choice>
    <choice value="Tokyo">Tokyo</choice>
  </picker>
  <txt ontask={load} taskid={city}>{status}</txt>
  <scrollview height={120}>
    <lazyvstack>
      {#each rows as row (row)}
        <txt onappear={() => visible++} ondisappear={() => visible--}>
          Row {row}
        </txt>
      {/each}
    </lazyvstack>
  </scrollview>
  <txt color="secondary">{visible} rows on screen</txt>
</vstack>
```

### Accessibility

| Attribute          | Type                                                  | Description                                                                                                                                                                          |
| ------------------ | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `a11ylabel`        | `string`                                              | The label that VoiceOver reads for the element, in place of its own label.                                                                                                           |
| `a11yvalue`        | `string \| number`                                    | The value that VoiceOver reads for the element, such as a rating.                                                                                                                    |
| `a11yhint`         | `string`                                              | A hint that VoiceOver reads after the label, describing what happens when the user activates the element.                                                                            |
| `a11yinputlabels`  | `Array<string>`                                       | The names that Voice Control accepts for the element, in addition to its label.                                                                                                      |
| `a11ytraits`       | `AccessibilityTrait \| Array<AccessibilityTrait>`     | Adds accessibility traits, such as `button`, `header`, or `selected`, to the element.                                                                                                |
| `a11yremovetraits` | `AccessibilityTrait \| Array<AccessibilityTrait>`     | Removes accessibility traits from the element, using the same names as `a11ytraits`.                                                                                                 |
| `a11yheading`      | `true \| "unspecified" \| 1 \| 2 \| 3 \| 4 \| 5 \| 6` | Marks the element as a heading: `true` for no specific level, or a level from `1` to `6`.                                                                                            |
| `a11ysortpriority` | `number`                                              | The VoiceOver order of the element. Elements with higher priorities are visited first.                                                                                               |
| `a11ychildren`     | `"combine" \| "contain" \| "ignore"`                  | How the children are grouped for VoiceOver: `combine` merges them into one element, `contain` groups them under the element, and `ignore` hides them behind the element's own label. |
| `a11yhidden`       | `boolean`                                             | Hides the element from assistive technologies.                                                                                                                                       |
| `a11yactions`      | `Array<string>`                                       | The names of custom actions that VoiceOver lists in its Actions rotor. Each one calls `ona11yaction` with its name.                                                                  |
| `ona11yaction`     | `(name: string) => void`                              | Runs when the user picks one of the `a11yactions` from the VoiceOver rotor, with that action's name.                                                                                 |
| `ona11yactivate`   | `() => void`                                          | Runs when VoiceOver activates the element by default, such as with a double tap.                                                                                                     |
| `ona11yescape`     | `() => void`                                          | Runs when the VoiceOver escape gesture is used on the element.                                                                                                                       |
| `ona11ymagictap`   | `() => void`                                          | Runs when the VoiceOver magic tap gesture is used on the element.                                                                                                                    |
| `ona11yadjust`     | `(direction: "increment" \| "decrement") => void`     | Runs when the VoiceOver increment or decrement gesture is used on the element, with `increment` or `decrement`.                                                                      |
| `testid`           | `string`                                              | The accessibility identifier for UI tests. On a container, it applies to the children too, unless `a11ychildren` is `contain`.                                                       |

```svelte
<script lang="ts">
  let rating = $state(3);
  let favorite = $state(false);
  let playing = $state(false);
  let shared = $state(false);
</script>

<vstack
  alignment="leading"
  spacing={16}
  padding
  ona11ymagictap={() => (playing = !playing)}
  ona11yescape={() => (favorite = false)}
>
  <txt font="title2" weight="bold" a11yheading={1}>Accessibility</txt>
  <hstack
    a11ychildren="ignore"
    a11ylabel="Rating"
    a11yvalue="{rating} of 5 stars"
    ona11yadjust={(direction) =>
      (rating = Math.min(
        5,
        Math.max(1, rating + (direction === "increment" ? 1 : -1)),
      ))}
  >
    {#each [1, 2, 3, 4, 5] as star (star)}
      <sfsymbol name={star <= rating ? "star.fill" : "star"} color="yellow" />
    {/each}
  </hstack>
  <hstack
    testid="favorite"
    a11ychildren="combine"
    a11yhint="Adds the article to your favorites"
    a11yinputlabels={["Favorite", "Heart"]}
    a11ytraits={favorite ? ["button", "selected"] : "button"}
    a11yremovetraits="image"
    a11yactions={["Share"]}
    ona11yaction={() => (shared = true)}
    ona11yactivate={() => (favorite = !favorite)}
    ontap={() => (favorite = !favorite)}
  >
    <sfsymbol name={favorite ? "heart.fill" : "heart"} color="pink" />
    <txt>Favorite</txt>
  </hstack>
  <txt a11ysortpriority={1}>VoiceOver reads this line first.</txt>
  <sfsymbol name="sparkles" a11yhidden />
  <txt color="secondary">
    {playing ? "Playing" : "Paused"}{shared ? ", shared" : ""}
  </txt>
</vstack>
```

### Grid cells

| Attribute         | Type                  | Description                                                                        |
| ----------------- | --------------------- | ---------------------------------------------------------------------------------- |
| `colspan`         | `number`              | The number of grid columns the element spans inside a `grid`.                      |
| `columnalignment` | `HorizontalAlignment` | The alignment of the element's whole column inside a `grid`.                       |
| `cellanchor`      | `UnitPointName`       | Where the element sits inside its grid cell, as a unit point such as `topLeading`. |

```svelte
<grid alignment="leading" hspacing={16} vspacing={12} padding>
  <gridrow>
    <txt weight="semibold" columnalignment="trailing">Name</txt>
    <txt>Ada Lovelace</txt>
  </gridrow>
  <gridrow>
    <txt weight="semibold">Born</txt>
    <txt>1815</txt>
  </gridrow>
  <gridrow>
    <circleshape fill="teal" width={12} height={12} cellanchor="topTrailing" />
    <txt>Wrote the first published algorithm for a computing machine.</txt>
  </gridrow>
  <gridrow>
    <txt colspan={2} maxwidth="infinity" padding={8} background="yellow">
      Spans both columns
    </txt>
  </gridrow>
</grid>
```

### List rows

| Attribute          | Type               | Description                                                                                                                  |
| ------------------ | ------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `tag`              | `string \| number` | Identifies a list row for selection, as a string or a number. `onselectionchange` receives this tag.                         |
| `rowinsets`        | `Insets`           | The insets of a list row: a number, or `{ top, leading, bottom, trailing }`, with `horizontal` and `vertical` as shorthands. |
| `rowseparator`     | `BarVisibility`    | Shows or hides the separator below a list row: `visible`, `hidden`, or `automatic`, or a boolean.                            |
| `rowseparatortint` | `Color`            | The color of a list row's separator.                                                                                         |
| `rowbackground`    | `ShapeStyle`       | The background style of a list row.                                                                                          |
| `deletedisabled`   | `boolean`          | Keeps the user from deleting the row with a swipe or in edit mode.                                                           |
| `movedisabled`     | `boolean`          | Keeps the user from moving the row in edit mode.                                                                             |

```svelte
<script lang="ts">
  import { move } from "swiftui-svelte";

  let rows = $state(["Pinned", "Second", "Third", "Fourth"]);
  let selected = $state<string | number | null>(null);
</script>

<list
  selection={selected}
  onselectionchange={(tag) => (selected = tag)}
  ondelete={(indices) =>
    (rows = rows.filter((_, index) => !indices.includes(index)))}
  onmove={({ from, to }) => move(rows, from, to)}
>
  {#each rows as row (row)}
    <txt
      tag={row}
      deletedisabled={row === "Pinned"}
      movedisabled={row === "Pinned"}
      rowbackground={row === "Pinned" ? "#FFCC0033" : undefined}
      rowseparatortint="orange">{row}</txt
    >
  {/each}
  <txt
    color="secondary"
    rowinsets={{ vertical: 16, horizontal: 32 }}
    rowseparator="hidden"
    deletedisabled
    movedisabled
  >
    Selected: {selected ?? "nothing"}
  </txt>
</list>
```

### Environment and feedback

| Attribute                 | Type                                                                   | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lang`                    | `string`                                                               | The locale of the element and everything inside it, such as `ar` or `en-US`. SwiftUI uses it to format dates and numbers, and text inside the element is shaped for that language, so that Turkish `f` and dotted `i` stay apart. Without `lang`, text is shaped for the app's preferred localization, as SwiftUI shapes a string literal. An empty `lang=""` shapes text without a language, as SwiftUI shapes `Text(verbatim:)` and text from a `String` variable, so the font can join `f` and `i` into a ligature. |
| `dir`                     | `"ltr" \| "rtl"`                                                       | The layout direction of the element and everything inside it: `ltr` or `rtl`.                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `dynamictypesize`         | `DynamicTypeSize \| { min?: DynamicTypeSize; max?: DynamicTypeSize; }` | Pins the Dynamic Type size, such as `xLarge`, or keeps it within `{ min, max }`.                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `colorscheme`             | `"light" \| "dark"`                                                    | Forces `light` or `dark` mode on the element and everything inside it.                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `preferredcolorscheme`    | `"light" \| "dark"`                                                    | Asks the window, sheet, or popover that contains the element to use `light` or `dark` mode.                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `disabled`                | `boolean`                                                              | Disables every control inside the element.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `sensoryfeedback`         | `SensoryFeedback`                                                      | The haptic feedback to play each time `feedbacktrigger` changes: a name such as `success` or `impact`, or an object describing an impact.                                                                                                                                                                                                                                                                                                                                                                              |
| `feedbacktrigger`         | `unknown`                                                              | The value to watch for `sensoryfeedback`. Feedback plays each time it changes.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `scrolldismisseskeyboard` | `"automatic" \| "immediately" \| "interactively" \| "never"`           | Whether scrolling hides the keyboard: `automatic`, `immediately`, `interactively`, or `never`.                                                                                                                                                                                                                                                                                                                                                                                                                         |

```svelte
<script lang="ts">
  let taps = $state(0);
  let locked = $state(true);
  let darkSheet = $state(false);
  let note = $state("");
</script>

<scrollview scrolldismisseskeyboard="interactively">
  <vstack spacing={16} padding>
    <datepicker value="2026-03-14" components="date" lang="ja-JP">
      <txt>Japanese dates</txt>
    </datepicker>
    <hstack dir="rtl" spacing={8}>
      <txt>1</txt>
      <txt>2</txt>
      <txt>3</txt>
    </hstack>
    <txt dynamictypesize="xxxLarge">Extra large text</txt>
    <txt dynamictypesize={{ max: "large" }}>Never larger than Large</txt>
    <vstack
      colorscheme="dark"
      padding
      background="systemBackground"
      radius={12}
    >
      <txt>Always dark</txt>
    </vstack>
    <toggle checked={locked} onchange={(next) => (locked = next)}>Lock</toggle>
    <vstack disabled={locked}>
      <btn
        variant="bordered"
        sensoryfeedback="success"
        feedbacktrigger={taps}
        onclick={() => taps++}
      >
        Tap for a haptic ({taps})
      </btn>
    </vstack>
    <textfield
      placeholder="Scroll to hide the keyboard"
      value={note}
      oninput={(value) => (note = value)}
    />
    <btn onclick={() => (darkSheet = true)}>Show a dark sheet</btn>
  </vstack>
</scrollview>
{#if darkSheet}
  <sheet detents={["medium"]} ondismiss={() => (darkSheet = false)}>
    <txt preferredcolorscheme="dark">This sheet asks for dark mode.</txt>
  </sheet>
{/if}
```

### Liquid Glass

| Attribute     | Type                                                                                                                                                         | Description                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `glasseffect` | `boolean \| "regular" \| "clear" \| "identity" \| { variant?: "regular" \| "clear" \| "identity"; tint?: Color; interactive?: boolean; shape?: ClipShape; }` | Draws Liquid Glass behind the element on iOS 26 and later, in a capsule unless a `shape` is set. Earlier versions draw the element without glass. |
| `glassid`     | `string \| number`                                                                                                                                           | Identifies a glass shape inside a `glasseffectcontainer`, so one shape can morph into another as elements appear and disappear.                   |
| `glassunion`  | `string \| number`                                                                                                                                           | Groups elements inside a `glasseffectcontainer` so that they share one glass shape.                                                               |

```svelte
<script lang="ts">
  let expanded = $state(false);
</script>

<zstack
  padding={32}
  background={{
    linear: ["teal", "indigo"],
    start: "topLeading",
    end: "bottomTrailing",
  }}
  radius={24}
>
  <glasseffectcontainer spacing={20}>
    <hstack spacing={20}>
      <btn onclick={() => (expanded = !expanded)}>
        <sfsymbol
          name="paintbrush.fill"
          font="title"
          width={56}
          height={56}
          glasseffect={{ interactive: true }}
          glassid="brush"
        />
      </btn>
      {#if expanded}
        <sfsymbol
          name="eraser.fill"
          font="title"
          width={56}
          height={56}
          glasseffect
          glassid="eraser"
        />
        <sfsymbol
          name="scissors"
          font="title"
          width={56}
          height={56}
          glasseffect="clear"
          glassunion="tools"
        />
        <sfsymbol
          name="ruler"
          font="title"
          width={56}
          height={56}
          glasseffect="clear"
          glassunion="tools"
        />
      {/if}
    </hstack>
  </glasseffectcontainer>
</zstack>
```

### Search suggestions

| Attribute    | Type     | Description                                                                                    |
| ------------ | -------- | ---------------------------------------------------------------------------------------------- |
| `completion` | `string` | The text that fills the search field when the user taps this suggestion inside a `searchable`. |

```svelte
<script lang="ts">
  const cities = ["Amsterdam", "Berlin", "Chicago", "Lisbon", "Tokyo"];
  let query = $state("");
  const suggestions = $derived(
    query === ""
      ? []
      : cities.filter((city) =>
          city.toLowerCase().startsWith(query.toLowerCase()),
        ),
  );
</script>

<list>
  <txt color="secondary">Type a letter to see suggestions.</txt>
</list>
<searchable value={query} oninput={(value) => (query = value)} prompt="Cities">
  {#each suggestions as city (city)}
    <labelview title={city} symbol="building.2" completion={city} />
  {/each}
</searchable>
```

### Tailwind CSS

| Attribute   | Type                                                                                                              | Description                                                                                                                                                                                                                                                                                           |
| ----------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `class`     | `string`                                                                                                          | Tailwind CSS utility classes, such as `p-4 bg-white dark:bg-neutral-800`, that set this element's attributes. They're resolved at build time, and explicit attributes on the element take precedence. Utilities without a native equivalent produce a build warning. See [Tailwind CSS](tailwind.md). |
| `margin`    | `{ top?: number \| "auto"; leading?: number \| "auto"; bottom?: number \| "auto"; trailing?: number \| "auto"; }` | The space outside the element on each edge, in points, or "auto" to share the free space and center the element along that axis. Margin sits outside the background, border, and shadow, unlike padding.                                                                                              |
| `container` | `string`                                                                                                          | Makes the element a query container for                                                                                                                                                                                                                                                               |
| `css`       | `boolean`                                                                                                         | Marks a stack as a CSS grid or flex container, so its children stretch across it as they do in CSS. The grid and flex classes set this.                                                                                                                                                               |
| `axis`      | `"horizontal" \| "vertical"`                                                                                      | The direction a CSS stack lays out its children in: `horizontal` for a row and `vertical` for a column. The flex and grid classes set this.                                                                                                                                                           |
| `boxsizing` | `"content-box" \| "border-box"`                                                                                   | How a width or height is measured. `border-box` counts the padding and border inside the size, as CSS does, and `content-box` adds them outside it. The sizing classes set `border-box`, and the default is `content-box`.                                                                            |
| `selfalign` | `"start" \| "center" \| "end" \| "stretch"`                                                                       | How this element aligns across its stack: start, center, end, or stretch. The self-* and justify-self-* classes set this.                                                                                                                                                                             |
| `balanced`  | `boolean`                                                                                                         | Balances the lines of a text element, so they come out an even width. The text-balance class sets this.                                                                                                                                                                                               |

```svelte
<hstack class="items-center gap-2">
  <btn
    class="cursor-pointer p-2 text-neutral-800 opacity-80 transition-opacity hover:opacity-100 active:opacity-100 dark:text-neutral-50"
    onclick={() => {}}
  >
    <sfsymbol
      name="plus.diamond"
      size={20}
      weight="semibold"
      label="yeni sözcük öner"
    />
  </btn>
  <btn
    class="cursor-pointer p-2 text-neutral-800 opacity-80 transition-opacity hover:opacity-100 active:opacity-100 dark:text-neutral-50"
    onclick={() => {}}
  >
    <sfsymbol
      name="envelope"
      size={20}
      weight="semibold"
      label="iletişime geç"
    />
  </btn>
</hstack>
<vstack
  class="mt-2 gap-2 rounded-lg border-t border-neutral-300 pt-2 dark:border-neutral-700"
  css
  axis="vertical"
  container=""
>
  <txt
    boxsizing="border-box"
    width={160}
    border={{ width: 2, color: "orange" }}
  >
    Sized with its border inside
  </txt>
  <txt
    margin={{ leading: "auto", trailing: "auto" }}
    balanced
    class="text-sm text-neutral-600 dark:text-neutral-300"
  >
    Centered with margin, and balanced across its lines
  </txt>
  <txt selfalign="end" class="text-sm text-neutral-600 dark:text-neutral-300">
    Aligned to the end of the stack
  </txt>
  <txt class="text-sm text-neutral-600 dark:text-neutral-300">
    Borders take space, like padding
  </txt>
</vstack>
```

### Tailwind native utilities

```svelte
<vstack
  class="gap-3 rounded-xl corner-squircle bg-neutral-100 p-4 dark:bg-neutral-900"
>
  <txt class="text-neutral-800 dark:text-neutral-50">Native variants</txt>
  <txt class="ios:text-blue-600 android:text-green-600 web:text-red-600">
    Blue on iOS, green on Android
  </txt>
  <txt
    class="contrast-more:font-bold portrait:text-neutral-700 landscape:text-neutral-500 dark:portrait:text-neutral-300 dark:landscape:text-neutral-400"
  >
    Bold with Increase Contrast
  </txt>
  <txt class="label-color">Label color from platformColor</txt>
  <hstack class="items-center gap-2">
    <btn
      class="cursor-pointer rounded-full bg-brand-500 p-2 text-white elevation-md ripple-brand-500"
      onclick={() => {}}
    >
      <sfsymbol name="star.fill" size={16} label="favorite" />
    </btn>
  </hstack>
  <vstack class="hairline rounded-lg p-3">
    <txt class="text-sm text-neutral-600 dark:text-neutral-300"
      >Hairline border</txt
    >
  </vstack>
</vstack>
```

## Value types

The attribute types above refer to these types from `src/elements.ts`.

### `AccessibilityTrait`

```ts
type AccessibilityTrait =
  | "button"
  | "header"
  | "link"
  | "image"
  | "selected"
  | "modal"
  | "toggle"
  | "staticText"
  | "searchField"
  | "summaryElement"
  | "updatesFrequently"
  | "playsSound"
  | "startsMediaSession"
  | "keyboardKey"
  | "allowsDirectInteraction"
  | "causesPageTurn";
```

### `AnimationOptions`

An animation: a curve name, or an object that sets the curve and its timing. `true` uses the default curve, and `false` turns the animation off.

```ts
type AnimationOptions = AnimationOptions;
```

### `BarVisibility`

```ts
type BarVisibility = boolean | "automatic" | "visible" | "hidden";
```

### `BlendMode`

```ts
type BlendMode =
  | "normal"
  | "multiply"
  | "screen"
  | "overlay"
  | "darken"
  | "lighten"
  | "color-dodge"
  | "color-burn"
  | "soft-light"
  | "hard-light"
  | "difference"
  | "exclusion"
  | "hue"
  | "saturation"
  | "color"
  | "luminosity"
  | "plus-lighter"
  | "plus-darker";
```

### `ButtonFeedback`

```ts
type ButtonFeedback = Omit<Modifiers, "pressed" | "hovered">;
```

### `ClipShape`

```ts
type ClipShape =
  | "rectangle"
  | "circle"
  | "capsule"
  | "ellipse"
  | number
  | { cornerradius: number }
  | {
      /** The radius in points of the top leading corner. */
      topleading?: number;
      /** The radius in points of the top trailing corner. */
      toptrailing?: number;
      /** The radius in points of the bottom leading corner. */
      bottomleading?: number;
      /** The radius in points of the bottom trailing corner. */
      bottomtrailing?: number;
    }
  | {
      /** SVG path data for the shape. */
      d: string;
      /** The SVG `viewBox` that the path scales to fit. */
      viewbox?: string;
    };
```

### `Color`

A color: a SwiftUI or UIKit system color name, or a CSS color string.

```ts
type Color =
  | NamedColor
  | SystemColor
  | `#${string}`
  | `rgb(${string})`
  | `rgba(${string})`
  | `hsl(${string})`
  | `hsla(${string})`;
```

### `ColumnWidth`

```ts
type ColumnWidth = number | { min?: number; ideal?: number; max?: number };
```

### `Curve`

```ts
type Curve =
  | "default"
  | "linear"
  | "easeIn"
  | "easeOut"
  | "easeInOut"
  | "spring"
  | "bouncy"
  | "smooth"
  | "snappy"
  | "timingCurve";
```

### `Detent`

```ts
type Detent = "medium" | "large" | number;
```

### `DragEvent`

The payload of `ondrag`: the drag's phase, positions in points, and velocity in points per second.

```ts
type DragEvent = {
  /** `changed` while the finger moves, and `ended` when it lifts. */
  phase: GesturePhase;
  /** The current position of the finger in the element's coordinates. */
  location: GesturePoint;
  /** The position where the drag started. */
  start: GesturePoint;
  /** The distance the finger has moved since the drag started. */
  translation: GesturePoint;
  /** The speed of the finger in points per second. */
  velocity: GesturePoint;
  /** Where the drag would end if the finger kept moving at its current speed and slowed down. */
  predictedEnd: GesturePoint;
};
```

### `DynamicTypeSize`

```ts
type DynamicTypeSize =
  | "xSmall"
  | "small"
  | "medium"
  | "large"
  | "xLarge"
  | "xxLarge"
  | "xxxLarge"
  | "accessibility1"
  | "accessibility2"
  | "accessibility3"
  | "accessibility4"
  | "accessibility5";
```

### `Edge`

```ts
type Edge = "top" | "bottom" | "leading" | "trailing";
```

### `EdgeSet`

```ts
type EdgeSet = Edge | "all" | "horizontal" | "vertical";
```

### `FieldVariant`

```ts
type FieldVariant = "automatic" | "plain" | "roundedBorder";
```

### `Font`

```ts
type Font =
  | "largeTitle"
  | "title"
  | "title2"
  | "title3"
  | "headline"
  | "subheadline"
  | "body"
  | "callout"
  | "footnote"
  | "caption"
  | "caption2";
```

### `GesturePhase`

```ts
type GesturePhase = "changed" | "ended";
```

### `GesturePoint`

```ts
type GesturePoint = { x: number; y: number };
```

### `GradientStop`

```ts
type GradientStop =
  | Color
  | {
      /** The color of the stop. */
      color: Color;
      /** The position of the stop along the gradient, from 0 to 1. */
      location: number;
    };
```

### `GridItem`

```ts
type GridItem =
  | number
  | (GridItemOptions & {
      /** A column or row of this fixed width in points. */
      fixed: number;
    })
  | (GridItemOptions & {
      /** As many columns or rows of at least this width in points as fit. */
      adaptive: number;
      /** The maximum width in points. */
      max?: number;
    })
  | (GridItemOptions & {
      /** The minimum width in points. */
      min?: number;
      /** The maximum width in points. */
      max?: number;
    });
```

### `GridItemOptions`

```ts
type GridItemOptions = {
  /** The space in points between this column or row and the next one. */
  spacing?: number;
  /** The alignment of the content inside the column or row. */
  alignment?: LayerAlignment;
};
```

### `HorizontalAlignment`

```ts
type HorizontalAlignment =
  | "leading"
  | "center"
  | "trailing"
  | "listRowSeparatorLeading"
  | "listRowSeparatorTrailing";
```

### `HoverEvent`

The payload of `onhover`: the pointer's phase, and its position in points unless the phase is `exit`.

```ts
type HoverEvent = {
  /** `enter` when the pointer arrives, `move` while it moves over the element, and `exit` when it leaves. */
  phase: "enter" | "move" | "exit";
  /** The pointer's `{ x, y }` in the element's coordinates. */
  location?: GesturePoint;
};
```

### `Inset`

```ts
type Inset = number | boolean;
```

### `Insets`

```ts
type Insets =
  | Inset
  | {
      /** The inset of the top edge, in points. */
      top?: Inset;
      /** The inset of the leading edge, in points. */
      leading?: Inset;
      /** The inset of the bottom edge, in points. */
      bottom?: Inset;
      /** The inset of the trailing edge, in points. */
      trailing?: Inset;
      /** The inset of the leading and trailing edges, in points. A shorthand for `leading` and `trailing`. */
      horizontal?: Inset;
      /** The inset of the top and bottom edges, in points. A shorthand for `top` and `bottom`. */
      vertical?: Inset;
    };
```

### `LayerAlignment`

```ts
type LayerAlignment =
  | "center"
  | "top"
  | "bottom"
  | "leading"
  | "trailing"
  | "topLeading"
  | "topTrailing"
  | "bottomLeading"
  | "bottomTrailing"
  | "leadingFirstTextBaseline"
  | "centerFirstTextBaseline"
  | "trailingFirstTextBaseline"
  | "leadingLastTextBaseline"
  | "centerLastTextBaseline"
  | "trailingLastTextBaseline";
```

### `Length`

```ts
type Length = number | "infinity";
```

### `MagnifyEvent`

The payload of `onmagnify`: the pinch's phase, its magnification, and its velocity.

```ts
type MagnifyEvent = {
  /** `changed` while the pinch continues, and `ended` when the fingers lift. */
  phase: GesturePhase;
  /** The scale of the pinch relative to its start. */
  magnification: number;
  /** The rate of change of the magnification per second. */
  velocity: number;
};
```

### `NamedColor`

```ts
type NamedColor =
  | "primary"
  | "secondary"
  | "accent"
  | "red"
  | "orange"
  | "yellow"
  | "green"
  | "mint"
  | "teal"
  | "cyan"
  | "blue"
  | "indigo"
  | "purple"
  | "pink"
  | "brown"
  | "gray"
  | "white"
  | "black"
  | "clear";
```

### `NumberFormat`

How a number field shows its value: `number`, `integer`, `percent`, or `{ currency }` with an ISO currency code.

```ts
type NumberFormat =
  | "number"
  | "integer"
  | "percent"
  | {
      /** An ISO 4217 currency code, such as `EUR`. */
      currency: string;
    };
```

### `Pinned`

```ts
type Pinned = "headers" | "footers" | "both";
```

### `Point`

```ts
type Point = { x?: number; y?: number };
```

### `PresentationOptions`

```ts
type PresentationOptions = {
  /** The heights the user can drag the presentation to: `medium`, `large`, a fraction of the screen such as `0.25`, or a height in points such as `300`. Defaults to `large`. */
  detents?: Array<Detent>;
  /** Shows the drag handle at the top: `visible`, `hidden`, or `automatic`. */
  dragindicator?: "automatic" | "visible" | "hidden";
  /** Whether the user can dismiss the presentation by swiping it away. Set it to `false` to keep it open. */
  dismissible?: boolean;
  /** Whether the user can use the content behind the presentation: `true`, `false`, or a detent such as `0.25` to allow it only up to that height. */
  backgroundinteraction?:
    | boolean
    | "automatic"
    | "enabled"
    | "disabled"
    | Detent;
  /** The corner radius of the presentation in points. */
  cornerradius?: number;
  /** The background behind the content: a color, material, or gradient, `clear` for none, or `{ glass }` for a Liquid Glass background (`regular` or `clear` on iOS 26, and a material before that). */
  presentationbackground?:
    | ShapeStyle
    | "clear"
    | { glass?: "regular" | "clear" };
  /** Runs when the user dismisses the presentation, so you can update your state. */
  ondismiss?: () => void;
};
```

### `RotateEvent`

The payload of `onrotate`: the rotation's phase, its angle, and its velocity.

```ts
type RotateEvent = {
  /** `changed` while the rotation continues, and `ended` when the fingers lift. */
  phase: GesturePhase;
  /** The angle of the rotation in degrees since it started. */
  degrees: number;
  /** The rate of rotation in degrees per second. */
  velocity: number;
};
```

### `RowMove`

The rows that moved in an `onmove` call: the positions they came from, and the position they moved to.

```ts
type RowMove = {
  /** The positions of the rows that moved, counted before the move. */
  from: Array<number>;
  /** The position the rows moved to, counted before the move. */
  to: number;
};
```

### `SafeAreaIgnoring`

```ts
type SafeAreaIgnoring =
  | boolean
  | "container"
  | "keyboard"
  | EdgeSet
  | Array<EdgeSet>
  | {
      /** The safe area regions to extend under: `all`, `container`, or `keyboard`. */
      regions?: "all" | "container" | "keyboard";
      /** The edges to extend under, as an edge, an array of edges, `all`, `horizontal`, or `vertical`. */
      edges?: EdgeSet | Array<EdgeSet>;
    };
```

### `ScrollGeometry`

The scroll position and sizes that `onscroll` receives, in points.

```ts
type ScrollGeometry = {
  /** The horizontal scroll offset from the leading edge. */
  x: number;
  /** The vertical scroll offset from the top edge. */
  y: number;
  /** The width of the visible area. */
  width: number;
  /** The height of the visible area. */
  height: number;
  /** The width of the scrollable content. */
  contentWidth: number;
  /** The height of the scrollable content. */
  contentHeight: number;
};
```

### `ScrollPhaseEvent`

The payload of `onscrollphase`: the scroll phase the content is in now.

```ts
type ScrollPhaseEvent = {
  /** The phase: `idle`, `tracking`, `interacting`, `decelerating`, or `animating`. */
  phase: "idle" | "tracking" | "interacting" | "decelerating" | "animating";
};
```

### `SearchScope`

A scope button for a `searchable` field: a string, or an object with a `value` and an optional `title`.

```ts
type SearchScope =
  | string
  | {
      /** The value that `selectedscope` and `onscopechange` use for this scope. */
      value: string;
      /** The text shown on the scope button. Defaults to `value`. */
      title?: string;
    };
```

### `SearchToken`

A token in a `searchable` field: a plain string, or an object with a `label`, and optionally an `id` and `symbol`.

```ts
type SearchToken =
  | string
  | {
      /** A unique identifier for the token. */
      id?: string | number;
      /** The text shown on the token. */
      label: string;
      /** The SF Symbol name shown on the token. */
      symbol?: string;
    };
```

### `SensoryFeedback`

```ts
type SensoryFeedback =
  | "success"
  | "warning"
  | "error"
  | "selection"
  | "increase"
  | "decrease"
  | "start"
  | "stop"
  | "alignment"
  | "levelChange"
  | "impact"
  | {
      /** The feedback type, which is `impact`. */
      type?: "impact";
      /** The weight of the impact: `light`, `medium`, or `heavy`. */
      weight?: "light" | "medium" | "heavy";
      /** How rigid the impact feels: `rigid`, `solid`, or `soft`. */
      flexibility?: "rigid" | "solid" | "soft";
      /** The strength of the impact, from 0 to 1. */
      intensity?: number;
    };
```

### `ShapeStyle`

A fill or foreground style: a color, a hierarchical style, a material, a color's gradient, or a gradient object.

```ts
type ShapeStyle =
  | Color
  | `${NamedColor}.gradient`
  | "tertiary"
  | "quaternary"
  | "quinary"
  | "ultraThinMaterial"
  | "thinMaterial"
  | "regularMaterial"
  | "thickMaterial"
  | "ultraThickMaterial"
  | "bar"
  | {
      /** The stops of a linear gradient, from `start` to `end`. */
      linear: Array<GradientStop>;
      /** The point where the gradient starts, such as `topLeading`. */
      start?: UnitPointName;
      /** The point where the gradient ends, such as `bottomTrailing`. */
      end?: UnitPointName;
    }
  | {
      /** The stops of a radial gradient, which grows outward from `center`. */
      radial: Array<GradientStop>;
      /** The point the gradient is centered on, such as `center`. */
      center?: UnitPointName;
      /** The radius in points where the gradient starts. */
      startRadius?: number;
      /** The radius in points where the gradient ends. */
      endRadius?: number;
    }
  | {
      /** The stops of an angular gradient, which sweeps around `center`. */
      angular: Array<GradientStop>;
      /** The point the gradient sweeps around, such as `center`. */
      center?: UnitPointName;
      /** The angle in degrees where the sweep starts. */
      startAngle?: number;
      /** The angle in degrees where the sweep ends. */
      endAngle?: number;
    };
```

### `Size`

A width and height in points.

```ts
type Size = {
  /** The width in points. */
  width: number;
  /** The height in points. */
  height: number;
};
```

### `SplitColumn`

```ts
type SplitColumn = "sidebar" | "content" | "detail";
```

### `SplitVisibility`

```ts
type SplitVisibility = "automatic" | "all" | "doubleColumn" | "detailOnly";
```

### `SymbolVariant`

```ts
type SymbolVariant = "fill" | "slash" | "circle" | "square" | "rectangle";
```

### `SystemColor`

```ts
type SystemColor =
  | "systemBackground"
  | "secondarySystemBackground"
  | "tertiarySystemBackground"
  | "systemGroupedBackground"
  | "secondarySystemGroupedBackground"
  | "tertiarySystemGroupedBackground"
  | "label"
  | "secondaryLabel"
  | "tertiaryLabel"
  | "quaternaryLabel"
  | "placeholderText"
  | "separator"
  | "opaqueSeparator"
  | "link"
  | "systemFill"
  | "secondarySystemFill"
  | "tertiarySystemFill"
  | "quaternarySystemFill"
  | "systemGray"
  | "systemGray2"
  | "systemGray3"
  | "systemGray4"
  | "systemGray5"
  | "systemGray6";
```

### `ToolbarPlacement`

```ts
type ToolbarPlacement =
  | "leading"
  | "trailing"
  | "bottom"
  | "principal"
  | "status"
  | "keyboard"
  | "navigation"
  | "primaryAction"
  | "secondaryAction"
  | "confirmationAction"
  | "cancellationAction"
  | "destructiveAction"
  | "automatic";
```

### `Transition`

```ts
type Transition = TransitionName | `${TransitionName} ${string}`;
```

### `TransitionName`

```ts
type TransitionName =
  | "opacity"
  | "fade"
  | "scale"
  | "slide"
  | "blur"
  | "move"
  | "push"
  | `move-${Edge}`
  | `push-${Edge}`;
```

### `UnitPointName`

```ts
type UnitPointName =
  | "center"
  | "top"
  | "bottom"
  | "leading"
  | "trailing"
  | "topLeading"
  | "topTrailing"
  | "bottomLeading"
  | "bottomTrailing";
```

### `VerticalAlignment`

```ts
type VerticalAlignment =
  | "top"
  | "center"
  | "bottom"
  | "firstTextBaseline"
  | "lastTextBaseline";
```

### `Weight`

```ts
type Weight =
  | "ultraLight"
  | "thin"
  | "light"
  | "regular"
  | "medium"
  | "semibold"
  | "bold"
  | "heavy"
  | "black";
```
