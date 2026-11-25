<script lang="ts">
  import { withAnimation } from "swiftui-svelte";
  import { onBackground } from "swiftui-svelte/app";
  import {
    ColorPicker,
    ConfirmationDialog,
    DisclosureGroup,
    FullScreenCover,
    Inspector,
    MultiDatePicker,
    MultiPicker,
    NumberField,
    Popover,
    SecureField,
    Sheet,
    TabView,
    TextEditor,
    TextField,
    Toggle,
  } from "swiftui-svelte/components";
  import { env } from "swiftui-svelte/env";
  import Mail from "./Mail.svelte";

  let count = $state(0);
  let seconds = $state(0);
  let name = $state("");
  let editingName = $state(false);
  let showSheet = $state(false);
  let celebrating = $state(false);
  let returns = $state(0);
  let stars = $state<number | null>(null);
  let fetchError = $state<string | null>(null);
  let showsLayouts = $state(false);
  let showsContent = $state(false);
  let bells = $state(0);
  let imageFailed = $state(false);
  let carouselOffset = $state(0);
  let carouselWidth = $state(0);
  let showsInputs = $state(false);
  let repeats = $state(0);
  let isFavorite = $state(false);
  let email = $state("");
  let password = $state("");
  let price = $state<number | null>(null);
  let notes = $state("");
  let journal = $state("");
  let showsPickers = $state(false);
  let toppings = $state<Array<string | number>>(["cheese"]);
  let sides = $state<Array<string | number>>([]);
  let deliveryDays = $state<Array<string>>([]);
  let highlight = $state<`#${string}`>("#FF9500");
  let isPinned = $state(false);
  let sortOrder = $state<string | number>("name");
  let lastAction = $state<string | null>(null);
  let showsPresentations = $state(false);
  let showsCover = $state(false);
  let showsPopover = $state(false);
  let showsInspector = $state(false);
  let confirmsDeletion = $state(false);
  let deleted = $state(false);
  let showsShortSheet = $state(false);
  let showsNavigation = $state(false);
  let showsToolbars = $state(false);
  let showsMail = $state(false);
  let page = $state(1);
  let barAction = $state<string | null>(null);
  let hidesNavBar = $state(false);
  let hidesTabBar = $state(true);
  let hidesBackButton = $state(false);
  let colorsNavBar = $state(false);
  let slide = $state<string | number>("first");

  const cards = [
    { value: "first", title: "First", color: "indigo" },
    { value: "second", title: "Second", color: "teal" },
    { value: "third", title: "Third", color: "orange" },
  ] as const;

  const swatches = [
    "red",
    "orange",
    "yellow",
    "green",
    "mint",
    "teal",
    "blue",
    "indigo",
    "purple",
    "pink",
  ] as const;

  async function loadStars() {
    fetchError = null;
    try {
      const response = await fetch(
        "https://api.github.com/repos/sveltejs/svelte",
      );
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const repo: unknown = await response.json();
      if (
        typeof repo === "object" &&
        repo != null &&
        "stargazers_count" in repo
      ) {
        stars = Number(repo.stargazers_count);
      }
    } catch (error) {
      fetchError = error instanceof Error ? error.message : String(error);
    }
  }

  $effect(() => {
    loadStars();
  });

  $effect(() => onBackground(() => returns++));

  $effect(() => {
    const interval = setInterval(() => seconds++, 1000);
    return () => clearInterval(interval);
  });
</script>

<navstack onpop={() => (showsToolbars = false)}>
  <screen title="Playground">
    <list>
      <vstack alignment="leading" spacing={8}>
        <txt font="headline">Counter</txt>
        <hstack spacing={16}>
          <btn onclick={() => withAnimation(() => count--, "bouncy")}>
            <sfsymbol name="minus.circle.fill" label="Decrease" font="title" />
          </btn>
          <txt size={34} design="rounded" weight="heavy">{count}</txt>
          <btn onclick={() => withAnimation(() => count++, "bouncy")}>
            <sfsymbol name="plus.circle.fill" label="Increase" font="title" />
          </btn>
        </hstack>
        <progressview value={Math.min(Math.max(count, 0), 10)} total={10} />
        <txt font="caption" color="secondary">Running for {seconds}s</txt>
        {#if returns > 0}
          <txt font="caption" color="secondary">
            {returns === 1
              ? "Welcome back. You've come back once."
              : `Welcome back. You've come back ${returns} times.`}
          </txt>
        {/if}
      </vstack>

      <vstack alignment="leading" spacing={8}>
        <TextField
          placeholder="Your name"
          debounce={150}
          bind:value={() => name, (value) => (name = value.slice(0, 12))}
          bind:focused={editingName}
        />
        {#if editingName}
          <btn variant="borderless" onclick={() => (editingName = false)}>
            Done editing
          </btn>
        {/if}
        {#if name.trim() !== ""}
          <txt color="accent">Hello, {name.trim()}!</txt>
        {/if}
        {#if env.keyboardHeight > 0}
          <txt font="caption" color="secondary">
            Keyboard: {Math.round(env.keyboardHeight)} pt
          </txt>
        {/if}
      </vstack>

      <hstack spacing={12}>
        <asyncimage
          src="https://github.com/sveltejs.png"
          width={48}
          height={48}
          radius={10}
        >
          <overlay alignment="bottomTrailing">
            <sfsymbol
              name="checkmark.seal.fill"
              label="Verified"
              color="accent"
              background="white"
              radius={8}
            />
          </overlay>
        </asyncimage>
        <vstack alignment="leading" spacing={2}>
          <txt font="headline" selectable>sveltejs/svelte</txt>
          {#if fetchError != null}
            <txt font="caption" color="red" lines={2}>{fetchError}</txt>
          {:else if stars == null}
            <txt font="caption" color="secondary">Loading stars…</txt>
          {:else}
            <txt font="caption" color="secondary">
              {stars.toLocaleString()} stars on GitHub
            </txt>
          {/if}
        </vstack>
        <spacer />
        <btn variant="borderless" onclick={loadStars}>
          <sfsymbol name="arrow.clockwise" label="Refresh" />
        </btn>
      </hstack>

      <btn variant="automatic" onclick={() => (showSheet = true)}>
        Show a sheet
      </btn>

      <DisclosureGroup title="Layouts" bind:expanded={showsLayouts}>
        <lazyvgrid columns={[{ adaptive: 44 }]} spacing={8} padding={4}>
          {#each swatches as color, index (color)}
            <zstack width={44} height={44} background={color} radius={10}>
              <txt font="caption" weight="bold" color="white">{index + 1}</txt>
            </zstack>
          {/each}
        </lazyvgrid>
        <grid alignment="leading" hspacing={24} vspacing={6}>
          <gridrow>
            <txt weight="semibold">Eager</txt>
            <txt weight="semibold">Lazy</txt>
          </gridrow>
          <divider colspan={2} />
          <gridrow>
            <txt design="monospaced">vstack</txt>
            <txt design="monospaced">lazyvstack</txt>
          </gridrow>
          <gridrow>
            <txt design="monospaced">hstack</txt>
            <txt design="monospaced">lazyhstack</txt>
          </gridrow>
        </grid>
        <hstack spacing={8} testid="shapes">
          <roundedrectangle
            cornerradius={10}
            fill={{
              linear: ["#ff3e00", "orange"],
              start: "topLeading",
              end: "bottomTrailing",
            }}
            width={40}
            height={40}
          />
          <circleshape
            fill="mint"
            stroke="teal"
            linewidth={3}
            dash={[5, 3]}
            width={40}
            height={40}
          />
          <capsule
            fill="regularMaterial"
            stroke="separator"
            width={40}
            height={24}
          />
          <unevenroundedrectangle
            topleading={20}
            bottomtrailing={20}
            fill="hsl(260 80% 60%)"
            width={40}
            height={40}
          />
          <pathshape
            d="M12 21C5 16 2 12.5 2 8.5 2 5.4 4.4 3 7.5 3c1.8 0 3.5.9 4.5 2.3C13 3.9 14.7 3 16.5 3 19.6 3 22 5.4 22 8.5 22 12.5 19 16 12 21z"
            viewbox="0 0 24 24"
            fill="rgb(255 45 85)"
            width={40}
            height={40}
          />
          <pathshape
            d="M12 12V2a10 10 0 1 1-10 10z"
            viewbox="0 0 24 24"
            fill={{ angular: ["blue", "purple", "blue"] }}
            width={40}
            height={40}
          />
        </hstack>
        <scrollview
          axes="horizontal"
          snap="view"
          indicators={false}
          onscroll={(scroll) => (carouselOffset = Math.round(scroll.x))}
          onresize={(size) => (carouselWidth = Math.round(size.width))}
        >
          <hstack spacing={12}>
            {#each swatches as color, index (color)}
              <zstack width={140} height={72} background={color} radius={12}>
                <txt weight="bold" color="white">Card {index + 1}</txt>
              </zstack>
            {/each}
          </hstack>
        </scrollview>
        <txt font="caption" color="secondary">
          Scrolled {carouselOffset} pt across a {carouselWidth} pt carousel
        </txt>
        <viewthatfits axes="horizontal">
          <txt lines={1}
            >This whole sentence shows when it fits on one line.</txt
          >
          <txt lines={1}>A shorter fallback</txt>
        </viewthatfits>
        <groupbox title="GroupBox">
          <txt>Content inside a GroupBox.</txt>
        </groupbox>
      </DisclosureGroup>

      <DisclosureGroup title="Content" bind:expanded={showsContent}>
        <hstack spacing={16}>
          <imageview
            name="Logo"
            fit="fit"
            width={40}
            height={40}
            label="swiftui-svelte logo"
          />
          <imageview
            file="logo-mono.png"
            fit="fit"
            width={40}
            height={40}
            decorative
          />
          <sfsymbol
            name="wifi"
            value={0.5}
            font="title"
            label="Wi-Fi at half strength"
          />
          <sfsymbol
            name="heart"
            variant="circle fill"
            rendering="palette"
            colors={["white", "pink"]}
            font="title"
          />
          <sfsymbol
            name="bell"
            effect="bounce"
            trigger={bells}
            font="title"
            label="Bell"
          />
          <sfsymbol
            name="waveform"
            effect="variableColor"
            font="title"
            color="accent"
          />
        </hstack>
        <btn variant="borderless" onclick={() => bells++}>Ring the bell</btn>
        <labelview title="Inbox" symbol="tray.fill" />
        <linkview href="https://svelte.dev">Svelte docs</linkview>
        <sharelink
          item="https://github.com/firatciftci/swiftui-svelte"
          subject="swiftui-svelte"
          title="Share this project"
        />
        <hstack spacing={12}>
          <asyncimage
            src="https://github.com/swiftui-svelte-missing-user-0000.png"
            width={40}
            height={40}
            onerror={() => (imageFailed = true)}
          >
            <failure>
              <sfsymbol
                name="photo.badge.exclamationmark"
                color="red"
                font="title"
                label="Image failed to load"
              />
            </failure>
          </asyncimage>
          {#if imageFailed}
            <txt font="caption" color="secondary">
              The image didn't load, so its failure view is showing.
            </txt>
          {/if}
        </hstack>
      </DisclosureGroup>

      <DisclosureGroup title="Inputs" bind:expanded={showsInputs}>
        <hstack spacing={12}>
          <btn variant="glass">Glass</btn>
          <btn variant="glassProminent" bordershape="capsule">
            Prominent glass
          </btn>
          <btn
            variant="bordered"
            bordershape="circle"
            controlsize="large"
            testid="favorite-shape"
          >
            <sfsymbol name="heart.fill" label="Heart" />
          </btn>
        </hstack>
        <hstack spacing={12}>
          <btn variant="bordered" repeat onclick={() => repeats++}>
            Hold to repeat
          </btn>
          <txt testid="repeats" color="secondary">Repeated {repeats} times</txt>
        </hstack>
        <Toggle variant="button" bind:checked={isFavorite} testid="favorite">
          <labelview
            title="Favorite"
            symbol={isFavorite ? "star.fill" : "star"}
          />
        </Toggle>
        <TextField
          placeholder="Email"
          keyboard="email"
          contenttype="email"
          autocapitalize="never"
          autocorrect={false}
          submitlabel="next"
          bind:value={email}
          testid="email"
        />
        <SecureField
          placeholder="Password"
          contenttype="password"
          submitlabel="done"
          bind:value={password}
          testid="password"
        />
        <NumberField
          placeholder="Price"
          format={{ currency: "USD" }}
          submitlabel="done"
          bind:value={price}
          testid="price"
        />
        <txt testid="price-value" color="secondary">
          {price == null ? "No price" : `Price: ${price}`}
        </txt>
        <TextField
          placeholder="Notes, up to four lines"
          axis="vertical"
          lines={[2, 4]}
          bind:value={notes}
          testid="notes"
        />
        <TextEditor height={80} bind:value={journal} testid="journal" />
        <txt testid="journal-count" font="caption" color="secondary">
          {journal.length} characters
        </txt>
      </DisclosureGroup>

      <DisclosureGroup title="Pickers and menus" bind:expanded={showsPickers}>
        <MultiPicker
          label="Toppings"
          variant="navigation"
          bind:value={toppings}
        >
          <choice value="cheese">Cheese</choice>
          <choice value="olives">Olives</choice>
          <choice value="peppers">Peppers</choice>
          <choice value="mushrooms">Mushrooms</choice>
        </MultiPicker>
        <MultiPicker label="Sides" variant="menu" bind:value={sides}>
          <choice value="fries">Fries</choice>
          <choice value="salad">Salad</choice>
          <choice value="soup">Soup</choice>
        </MultiPicker>
        <ColorPicker bind:value={highlight} supportsopacity={false}>
          <labelview title="Highlight color" symbol="paintpalette" />
        </ColorPicker>
        <hstack spacing={8}>
          <circleshape fill={highlight} width={20} height={20} />
          <txt testid="highlight" font="caption" color="secondary"
            >{highlight}</txt
          >
        </hstack>
        <gauge value={0.6} current="60%">
          <txt>Storage</txt>
        </gauge>
        <hstack spacing={16}>
          <gauge value={0.6} current="60%" variant="circular">
            <txt>Storage</txt>
          </gauge>
          <gauge value={0.25} variant="circularCapacity" tint="green">
            <txt>Storage</txt>
          </gauge>
        </hstack>
        <labeledcontent title="Version" value="1.0.0" />
        <hstack spacing={16}>
          <menuview
            title="Actions"
            symbol="ellipsis.circle"
            testid="actions-menu"
          >
            <btn onclick={() => (lastAction = "Copy")}>
              <sfsymbol name="doc.on.doc" /><txt>Copy</txt>
            </btn>
            <btn onclick={() => (lastAction = "Duplicate")}>Duplicate</btn>
            <toggle checked={isPinned} onchange={(next) => (isPinned = next)}>
              Pin
            </toggle>
            <picker
              label="Sort by"
              value={sortOrder}
              onchange={(next) => (sortOrder = next)}
            >
              <choice value="name">Name</choice>
              <choice value="date">Date</choice>
            </picker>
            <menuview title="Share" symbol="square.and.arrow.up">
              <btn onclick={() => (lastAction = "Message")}>Message</btn>
              <btn onclick={() => (lastAction = "Mail")}>Mail</btn>
            </menuview>
            <divider />
            <sectionview>
              <btn role="destructive" onclick={() => (lastAction = "Delete")}>
                Delete
              </btn>
            </sectionview>
          </menuview>
          <menuview
            title="Add"
            symbol="plus"
            onprimaryaction={() => (lastAction = "Add")}
          >
            <btn onclick={() => (lastAction = "Photo")}>Photo</btn>
            <btn onclick={() => (lastAction = "File")}>File</btn>
          </menuview>
        </hstack>
        <txt testid="last-action" font="caption" color="secondary">
          {lastAction == null ? "No action yet" : `Last action: ${lastAction}`}
        </txt>
        <MultiDatePicker bind:value={deliveryDays}>
          <txt>Delivery days</txt>
        </MultiDatePicker>
        <txt testid="delivery-days" font="caption" color="secondary">
          {deliveryDays.length}
          {deliveryDays.length === 1 ? "day" : "days"} picked
        </txt>
        <contentunavailableview
          title="No favorites"
          symbol="star"
          description="Tap the star on any item to keep it here."
        >
          <btn variant="bordered">Browse items</btn>
        </contentunavailableview>
      </DisclosureGroup>

      <DisclosureGroup title="Presentations" bind:expanded={showsPresentations}>
        <btn onclick={() => (showsCover = true)}>Show a full-screen cover</btn>
        <btn onclick={() => (showsPopover = true)}>
          Show a popover
          <Popover bind:presented={showsPopover} adaptation="popover">
            <txt padding width={260}>
              Popovers point at the button that opened them.
            </txt>
          </Popover>
        </btn>
        <btn onclick={() => (showsInspector = true)}>Show the inspector</btn>
        <btn role="destructive" onclick={() => (confirmsDeletion = true)}>
          Delete all photos
          <ConfirmationDialog
            bind:presented={confirmsDeletion}
            title="Delete all photos?"
            titlevisibility="visible"
          >
            <txt>This can't be undone.</txt>
            <btn role="destructive" onclick={() => (deleted = true)}>Delete</btn
            >
            <btn role="cancel">Cancel</btn>
          </ConfirmationDialog>
        </btn>
        {#if deleted}
          <txt font="caption" color="secondary">Photos deleted</txt>
        {/if}
        <btn onclick={() => (showsShortSheet = true)}>Show a short sheet</btn>

        <FullScreenCover bind:presented={showsCover}>
          <vstack spacing={16} padding>
            <sfsymbol name="rectangle.inset.filled" font="largeTitle" />
            <txt font="title2" weight="semibold">A full-screen cover</txt>
            <txt color="secondary" align="center">
              It covers the whole screen and doesn't close with a swipe.
            </txt>
            <btn variant="prominent" onclick={() => (showsCover = false)}>
              Close
            </btn>
          </vstack>
        </FullScreenCover>
        <Sheet
          bind:presented={showsShortSheet}
          detents={[0.25, "medium"]}
          dragindicator="visible"
          backgroundinteraction={0.25}
        >
          <txt padding color="secondary">
            Drag the handle to resize this sheet. You can still use the list
            behind it.
          </txt>
        </Sheet>
      </DisclosureGroup>

      <DisclosureGroup title="Navigation" bind:expanded={showsNavigation}>
        <btn onclick={() => (showsToolbars = true)}>
          Open a screen with toolbars
        </btn>
        <btn onclick={() => (showsMail = true)}>Open a split view</btn>
        <FullScreenCover bind:presented={showsMail}>
          <Mail onclose={() => (showsMail = false)} />
        </FullScreenCover>
        <txt font="caption" color="secondary">Swipe between pages</txt>
        <TabView
          bind:selection={slide}
          variant="page"
          indexdisplay="always"
          height={140}
          testid="carousel"
        >
          {#each cards as card (card.value)}
            <tab title={card.title} value={card.value}>
              <zstack>
                <roundedrectangle cornerradius={16} fill={card.color} />
                <txt font="title2" weight="semibold" color="white">
                  {card.title}
                </txt>
              </zstack>
            </tab>
          {/each}
        </TabView>
      </DisclosureGroup>
    </list>

    <Inspector
      bind:presented={showsInspector}
      detents={["medium", "large"]}
      dragindicator="visible"
    >
      <vstack spacing={12} padding>
        <txt font="headline">Inspector</txt>
        <txt color="secondary">
          On iPad, this opens as a column beside the content.
        </txt>
      </vstack>
    </Inspector>
    <Sheet detent="medium" bind:presented={showSheet}>
      <vstack spacing={16} padding>
        <sfsymbol name="sparkles" font="largeTitle" color="accent" />
        <txt font="title2" weight="semibold">Hello from a sheet</txt>
        <txt color="secondary">
          The counter is at <txt weight="bold" color="primary">{count}</txt>.
        </txt>
        <txt
          font="footnote"
          color="secondary"
          markdown="Rendered by **[Svelte](https://svelte.dev)** as native **SwiftUI**."
        />
        <btn onclick={() => (celebrating = !celebrating)}>
          {celebrating ? "Calm down" : "Celebrate"}
        </btn>
        {#if celebrating}
          <sfsymbol
            name="party.popper.fill"
            label="Party popper"
            font="largeTitle"
            color="orange"
            transition="scale opacity"
            animation="bouncy"
          />
        {/if}
        <btn variant="prominent" onclick={() => (showSheet = false)}>
          Done
        </btn>
      </vstack>
    </Sheet>
  </screen>

  {#if showsToolbars}
    <screen
      title="Toolbars"
      subtitle="Items in every placement"
      titledisplaymode="inline"
      navbarvisibility={hidesNavBar ? "hidden" : "automatic"}
      tabbarvisibility={hidesTabBar ? "hidden" : "automatic"}
      backbuttonhidden={hidesBackButton}
      navbarbackground={colorsNavBar ? "mint" : undefined}
    >
      <list>
        <txt color="secondary">
          Toolbar items sit in the navigation bar, the bottom bar, and the More
          menu.
        </txt>
        <Toggle bind:checked={hidesNavBar}>Hide the navigation bar</Toggle>
        <Toggle bind:checked={hidesTabBar}>Hide the tab bar</Toggle>
        <Toggle bind:checked={hidesBackButton}>Hide the back button</Toggle>
        <Toggle bind:checked={colorsNavBar}>Color the navigation bar</Toggle>
        <txt testid="bar-action" font="caption" color="secondary">
          {barAction == null ? "No action yet" : `Last action: ${barAction}`}
        </txt>
      </list>
      <toolbar placement="primaryAction">
        <menuview title="Edit" symbol="pencil.circle" testid="toolbar-menu">
          <btn onclick={() => (barAction = "Duplicate")}>Duplicate</btn>
          <btn onclick={() => (barAction = "Rename")}>Rename</btn>
        </menuview>
      </toolbar>
      <toolbar placement="secondaryAction">
        <btn onclick={() => (barAction = "Pin")}>Pin</btn>
        <btn onclick={() => (barAction = "Share")}>Share</btn>
      </toolbar>
      <toolbar placement="bottom">
        <btn onclick={() => (page = Math.max(page - 1, 1))}>
          <sfsymbol name="chevron.backward" label="Previous page" />
        </btn>
      </toolbar>
      <toolbarspacer placement="bottom" />
      <toolbar placement="bottom">
        <txt testid="page">Page {page} of 3</txt>
      </toolbar>
      <toolbarspacer placement="bottom" />
      <toolbar placement="bottom">
        <btn onclick={() => (page = Math.min(page + 1, 3))}>
          <sfsymbol name="chevron.forward" label="Next page" />
        </btn>
      </toolbar>
    </screen>
  {/if}
</navstack>
