# Elements

The [element reference](reference.md) lists every element and the modifiers that all elements take, with the type of each attribute and an example. This page explains how the elements behave: the details that don't fit in a table, and the features that several elements share.

A few details:

- **Buttons.** `variant` is `automatic`, `borderless` (the default), `plain`, `bordered`, `prominent`, `glass`, or `glassProminent`. The two glass styles need iOS 26 and fall back to `bordered` and `prominent` on earlier versions. With `variant="automatic"`, a button in a list makes its whole row tappable. `role` is `destructive` or `cancel`, or on iOS 26, `confirm` or `close`. `bordershape` is `capsule`, `circle`, `roundedRectangle`, or a corner radius in points, and applies to bordered and glass buttons. With `repeat`, holding the button down fires `onclick` again and again, as a stepper does.
- **Toggles.** `variant="switch"` always draws a switch, and `variant="button"` draws a button that stays highlighted while it's on.
- **Stacks.** `alignment` takes any of SwiftUI's alignment guides. On a `vstack` that's `leading`, `center`, `trailing`, `listRowSeparatorLeading`, or `listRowSeparatorTrailing`. On an `hstack` it's `top`, `center`, `bottom`, `firstTextBaseline`, or `lastTextBaseline`, which lines up text of different sizes. A `zstack` takes a corner or edge such as `topLeading`, or a baseline alignment such as `leadingFirstTextBaseline`. A `spacer` with `minlength` never shrinks below that many points.
- **Text.** `lines` caps the number of lines, and `truncation` picks where the text is cut off when it doesn't fit: `head`, `middle`, or `tail`. `minscale` lets the text shrink to that fraction of its size before it truncates. `align` sets the alignment of wrapped text: `leading`, `center`, or `trailing`. `linespacing` adds points of space between lines, `kerning` and `tracking` adjust the space between letters, and `selectable` lets the user select and copy the text.
- **Whitespace.** On the web, the browser collapses the line breaks and indentation inside text, and Svelte leaves that work to it, so `txt` does the same: every run of spaces, tabs, and line breaks becomes one space, and spaces at the start and end are dropped. This way, text that a formatter wraps across lines still reads as one line. Set `whitespace="pre-line"` to keep line breaks, which you'll want for text that users type, or `whitespace="pre"` to keep every space.
- **Fonts.** `font` picks a text style that follows Dynamic Type, such as `headline` or `caption`. `size` sets a fixed size in points instead, like `.system(size:)`, so it doesn't follow Dynamic Type. `design` is `rounded`, `serif`, or `monospaced`, and `weight` goes from `ultraLight` to `black`. These work on any element and apply to all the text inside it.
- **Lazy stacks and grids.** `lazyvstack`, `lazyhstack`, `lazyvgrid`, and `lazyhgrid` create their children only as they scroll into view, so put them in a `scrollview`. Set `pinned` to `headers`, `footers`, or `both` to keep the header and footer of each `sectionview` on screen while its rows scroll by. A grid's `columns` (or `rows` for `lazyhgrid`) is a number of equal flexible columns, or an array of items: a number for a fixed width, `{ min, max }` for a flexible column, or `{ adaptive: 80 }` to fit as many columns of at least 80 points as there's room for. Any item can also take `spacing` and `alignment`.
- **Grids.** A `grid` lays out `gridrow` children as a table whose columns line up across rows. `spacing` sets both gaps, and `hspacing` and `vspacing` set them separately. Inside a grid, any element takes `colspan` to span several columns, `columnalignment` to align its whole column, and `cellanchor` to place itself in its cell. An element that isn't in a `gridrow`, like a `divider`, spans the whole width.
- **Fitting content.** A `viewthatfits` shows the first child that fits in the available space. `axes` limits the check to `horizontal` or `vertical`.
- **Groups.** A `group` applies its modifiers to each child without adding a container. A `groupbox` draws its children in a box, and a `controlgroup` joins buttons into one control. A `disclosuregroup` shows its children when the user expands it. Its `expanded` attribute and `ontoggle` event work like a toggle's `checked` and `onchange`, and the `DisclosureGroup` component supports `bind:expanded`. All three take a `title`, or a `label` child for a custom view.
- **Layout and effects.** `offset` and `position` take `{ x, y }` in points. `offset` moves the element without changing the layout around it, and `position` places the element's center in its parent's coordinate space. `rotation` turns the element by a number of degrees around `rotationanchor`, and `scale` takes a number, or `{ x, y }` to scale each axis, around `scaleanchor`. Both anchors take a unit point such as `center` or `topLeading`. `clipshape` and `contentshape` take `rectangle`, `circle`, `capsule`, `ellipse`, a corner radius, an object with `cornerradius` or with a radius for each corner (`topleading`, `toptrailing`, `bottomleading`, and `bottomtrailing`), or an SVG path as `{ d, viewbox }`. `border` takes a color or `{ color, width }`, and `shadow` takes a radius, a color, or `{ color, radius, x, y }`. A `maskview` child masks the element with its content. `ignoressafearea` is `true` for every edge, `keyboard` or `container` for only that region, an edge such as `top`, an array of edges, or `{ regions, edges }`. A `safeareainset` child pins its content to one `edge` of the element (`bottom` unless you set it) and insets the rest of the element's content to make room. That suits a bar under a scroll view. It also takes `alignment` and `spacing`.
- **Gestures.** `ontap` receives the tap's `{ x, y }` in the element's own coordinates, and `tapcount` sets how many taps it takes, such as `2` for a double tap. `onlongpress` fires after the user holds a finger down for `longpressduration` milliseconds. The default is 500 milliseconds. `ondrag` sends `{ phase, location, start, translation, velocity, predictedEnd }` as the finger moves. `phase` is `"changed"` while the finger moves and `"ended"` when it lifts. A drag starts once the finger moves `dragdistance` points, 10 by default. `onmagnify` sends `{ phase, magnification, velocity }` for a pinch, and `onrotate` sends `{ phase, degrees, velocity }` for a two-finger rotation. One two-finger gesture produces both, so a pinch usually reports some rotation too, and a rotation reports some magnification. Drags, pinches, and rotations are recognized alongside the element's other gestures, so a card can follow a drag while it scales. Velocities are per second. To move, scale, or rotate an element with its own gesture, put the handlers on a container that stays still and the `offset`, `scale`, or `rotation` on an element inside it. Otherwise the gesture measures the fingers against an element that is already changing under them.
- **Appearing and tasks.** `onappear` and `ondisappear` fire when SwiftUI shows and hides the element. For a row in a `list`, that happens as it scrolls into and out of view, so `onappear` on the last row can load the next page. `ontask` runs when the element appears, like SwiftUI's `.task`, and receives an `AbortSignal` that aborts when the element disappears. Pass the signal to `fetch` to cancel the request: `ontask={(signal) => load(signal)}`. Set `taskid` to run the task again whenever that value changes. SwiftUI cancels the previous run first, so its signal aborts too. An error from a task whose signal has aborted isn't reported.
- **Haptics and environment overrides.** `sensoryfeedback` takes `success`, `warning`, `error`, `selection`, `increase`, `decrease`, `start`, `stop`, `alignment`, `levelChange`, or `impact`, or an object such as `{ weight: "light", intensity: 0.5 }` or `{ flexibility: "soft" }` for an impact. SwiftUI plays it each time `feedbacktrigger` changes, so pass the value whose change the user should feel. `colorscheme` forces light or dark mode on the element and everything inside it. `preferredcolorscheme` requests that the window, sheet, or popover that contains the element use that mode. `dynamictypesize` pins text to one Dynamic Type size, such as `xLarge`, or keeps it within `{ min, max }`. `scrolldismisseskeyboard` on a `scrollview`, `list`, or `formview` sets whether scrolling hides the keyboard: `immediately`, `interactively`, `never`, or `automatic`. For buttons above the keyboard, use a `toolbar` with `placement="keyboard"`.
- **Liquid Glass.** On iOS 26 and later, `glasseffect` draws Liquid Glass behind the element, in a capsule unless you pick a shape. Write it as a bare attribute for regular glass, as `clear` or `identity`, or as an object: `{ variant, tint, interactive, shape }`, where `shape` takes the same values as `clipshape`. Earlier iOS versions draw the element without glass. Put elements with glass inside a `glasseffectcontainer` so that SwiftUI renders them together and blends shapes that are closer than its `spacing`. Wrap them in one stack inside the container, because the container doesn't lay out its children. Inside a container, elements with the same `glassunion` share one glass shape, and `glassid` lets a shape morph into another one as elements appear and disappear.
- **Scrolling.** A `scrollview` scrolls vertically unless you set `axes` to `horizontal` or `both`. Set `snap="paging"` to stop on each screen-sized page, or `snap="view"` to stop at the start of each child of the stack inside it, like a carousel. `indicators={false}` hides the scroll bars, `bounce="basedOnSize"` only bounces when the content is larger than the view, and `anchor="bottom"` starts at the bottom, as a chat does. `scrollview` and `list` both send `onscroll` with `{ x, y, width, height, contentWidth, contentHeight }`: the scroll offset from the top leading corner, the visible size, and the size of the content, all in points. To scroll from code, use a [ref](#element-refs-and-focus).
- **Pull to refresh.** Give a `list` or `scrollview` an `onrefresh` handler, and the user can pull it down to refresh. If the handler returns a promise, the spinner keeps spinning until the promise settles, so `onrefresh={async () => (items = await load())}` shows the new items as the spinner goes away. If the promise rejects, the spinner stops and the error shows up like any other error from your app.
- **Lists.** `variant` sets the list style: `plain`, `inset`, `grouped`, `insetGrouped`, `sidebar`, or `automatic`. To let the user select rows, give each row a `tag` and handle `onselectionchange` on the `list`, which receives the selected row's `tag`, or `null` when nothing is selected. With `multiple`, `selection` is an array of tags. Use the `List` and `MultiList` components for `bind:selection`. `editing` turns on edit mode, and `oneditingchange` reports when SwiftUI turns it on or off.
- **Deleting and moving rows.** Put `ondelete` or `onmove` on a `list` or a `sectionview` to let the user delete or reorder its rows, by swiping or in edit mode. `ondelete` receives the positions of the deleted rows among that element's children, and `onmove` receives `{ from, to }`: the positions of the rows that moved, and the position they moved to, counted before the move. Pass that straight to `move` from `swiftui-svelte` to reorder your array the same way: `onmove={({ from, to }) => move(items, from, to)}`. Add `deletedisabled` or `movedisabled` to a row to keep it in place.
- **Rows.** Any element in a list takes `rowinsets` (a number, or `{ top, leading, bottom, trailing }` with `horizontal` and `vertical` as shorthands), `rowseparator` (`hidden` or `visible`), `rowseparatortint`, and `rowbackground`. On iOS 26, `indexlabel` on a `sectionview` adds a letter to the list's section index, the column of letters along the trailing edge that jumps to each section. `sectionindex` on the `list` shows or hides it.
- **Sizes.** Any element sends `onresize` with its `{ width, height }` in points when it first appears and whenever its size changes, so you can lay out by size without SwiftUI's `GeometryReader`. The host only reports scroll and size changes for elements that have a handler.
- **Event handlers.** Handlers receive the new value itself, such as the text for `oninput` or the boolean for a toggle's `onchange`, rather than a DOM event. Because there's no event object, there's nothing to prevent or stop. To react to an event only once, keep a flag in your state and check it in the handler.
- **Text fields.** `oninput` fires on every keystroke. Set `debounce` to a number of milliseconds to wait until the user pauses typing instead, which helps when each change starts a search or a request. The field shows what the user types right away either way. Text that is still waiting is sent before any other event, so pressing Return, leaving the field, tapping a button, or closing the screen runs `oninput` first, and a Save button reads what the user typed. While the user composes text with an input method, such as Japanese or Chinese, the field shows the text being composed and waits until the user confirms it before `oninput` runs, so a handler that changes the text, such as one that uppercases it, doesn't break the composition. With `axis="vertical"`, the field grows as the user types more lines, up to `lines`, which is a maximum such as `4` or a range such as `[2, 4]`. `variant` is `plain` or `roundedBorder`.
- **Keyboards.** `textfield`, `securefield`, and `texteditor` take `keyboard` to pick the keyboard (such as `email`, `url`, `number`, `decimal`, or `phone`), and `contenttype` to tell iOS what the text is (such as `email`, `username`, `password`, `newPassword`, or `oneTimeCode`), so it can offer AutoFill and passwords. `autocapitalize` is `never`, `words`, `sentences`, or `characters`, `autocorrect={false}` turns off autocorrection, and `submitlabel` names the Return key: `done`, `go`, `next`, `search`, `send`, and so on.
- **Number fields.** A `textfield` with a `format` edits a number. `format` is `number`, `integer`, `percent`, or `{ currency: "EUR" }` with an ISO currency code. The field shows the value formatted, `value` is a number or `null`, and `oninput` receives the parsed number when the user presses Return or leaves the field, or `null` if they clear it. Use the `NumberField` component for `bind:value`.
- **Secure fields and text editors.** A `securefield` hides what the user types, for passwords. A `texteditor` edits many lines of text and scrolls; give it a `height`. Both work like a `textfield`, with `value`, `oninput`, `debounce`, and `focused`.
- **Images.** An `imageview` shows an image from the asset catalog with `name`, or a file in the app bundle with `file`, such as `file="photos/beach.jpg"`. It keeps the image's own size unless you set `fit` to `fit` or `fill` to scale it into its frame, `stretch` to fill the frame exactly, or `tile` to repeat it. `renderingmode="template"` draws it in the foreground color. VoiceOver reads an asset image's name unless you set `label`, and skips the image entirely with `decorative`.
- **Remote images.** `asyncimage` loads `src` and scales it to fit its frame, or to fill it with `fit="fill"`. Give it a `width` and `height`. It shows a spinner while it loads, or the children of a `placeholder` element, and the children of a `failure` element if the image can't load. `onload` fires when the image appears, and `onerror` receives the error message.
- **Symbols.** Without a `label`, VoiceOver reads an `sfsymbol` with SwiftUI's built-in description of the symbol. Set `label` to say what the icon does, especially on icon-only buttons: `<sfsymbol name="trash" label="Delete to-do" />`. `variant` adds variants like `fill` or `circle fill`, and `value` with a value from 0 to 1 fills a variable symbol such as `wifi` part of the way. `rendering` is `monochrome`, `hierarchical`, `palette`, or `multicolor`; with `palette`, `colors` lists up to three colors. `effect` animates the symbol. `pulse`, `variableColor`, `breathe`, `rotate`, `wiggle`, and `scale` run while `active` is true, which is the default. With a `trigger` value, every effect except `scale` plays once each time the value changes, and `bounce` only works this way.
- **Labels and links.** A `labelview` shows a `title` with an SF Symbol from `symbol`, an asset image from `image`, or the children of an `icon` element, and `variant` can show only the title or only the icon. A `linkview` opens `href` in the browser. A `sharelink` opens the share sheet for `item`, a URL or text, with an optional `subject` and `message`. Both use their children as the label, or `title` if you set it.
- **Forms.** `formview` gives a screen the grouped look of the Settings app. Group its rows with `sectionview`, which shows an optional `header` above the rows and `footer` below them. `sectionview` works inside a `list` too.
- **Tabs.** Give each `tab` a `value`, and set `selection` on the `tabview` to pick the tab that's showing. `onchange` receives the `value` of the tab the user switches to. A tab without a `value` uses its position, starting at 0. `badge` shows a number or a short label on the tab, and `0` or `""` hides it. `role="search"` makes the tab the search tab, which iOS 26 sets apart at the end of the tab bar. Group tabs in a `tabsection` with a `title`: on iPad with `variant="sidebarAdaptable"`, the user can open the tab bar as a sidebar, and each section is a group in it. `variant="page"` turns the tabs into pages the user swipes between, with dots below them that `indexdisplay` shows (`always`) or hides (`never`). On iOS 26, `minimize="onScrollDown"` shrinks the tab bar while the user scrolls.
- **Split views.** A `navsplitview` shows its first child as the sidebar and its last child as the detail column. With three children, the middle one is the content column. Each column is usually a `screen`, or a `navstack` when it pushes screens of its own, and `columnwidth` on a column sets its width to a number or to `{ min, ideal, max }`. `visibility` is `all`, `doubleColumn`, `detailOnly`, or `automatic`, and `variant` is `automatic`, `balanced`, or `prominentDetail`. SwiftUI changes the visibility too, for example to `doubleColumn` when three columns don't fit, and `onvisibilitychange` reports the new value. On iPhone, the columns collapse into a stack: `compactcolumn` (`sidebar`, `content`, or `detail`) picks the column that's showing, so set it to `detail` when the user picks an item. When the user goes back, `oncompactcolumnchange` receives the column they went back to. Use the `NavSplitView` component to bind both values.
- **Pickers.** Each `choice` is one option: its text is the title, its `value` is what `onchange` receives, and `symbol` adds an SF Symbol. `variant` is `automatic`, `menu`, `segmented`, `wheel`, `inline`, or `navigation`. With `navigation`, the options open on their own screen, so the picker has to be inside a `navstack`. Add `multiple` to let the user pick several options: `value` is then an array, and `onchange` receives the new array, in the order of the choices. A multiple picker shows its options as rows with checkmarks, or with `variant="menu"` or `variant="navigation"` (as a menu or a screen of rows). The picked titles appear next to the label. Use the `MultiPicker` component for `bind:value`.
- **Multiple dates.** A `multidatepicker` shows a calendar where the user taps days on and off. Its `value` is an array of days as `YYYY-MM-DD` strings, which don't depend on the time zone, and `min` and `max` limit the days the user can pick.
- **Color pickers.** A `colorpicker` takes any color for `value` and sends the color the user picks to `onchange` as a hex string such as `#FF9500`, or `#FF950080` when it's partly transparent. Set `supportsopacity={false}` to hide the opacity slider.
- **Gauges.** A `gauge` shows `value` between `min` and `max`, which default to 0 and 1. Its children are its label; `current`, `minlabel`, and `maxlabel` add short text for the value and the ends. `variant` is `circular`, `circularCapacity`, `linear`, or `linearCapacity`.
- **Labeled content.** A `labeledcontent` shows a `title` (or a `label` child) with a `value` on the trailing side, like a row in Settings. Without `value`, its children are the content.
- **Empty states.** A `contentunavailableview` fills the space with a `symbol`, a `title`, and a `description`, and its children become action buttons below them. With `variant="search"`, it shows the system's "No Results" message, mentioning `query` when you set it.
- **Menus.** A `menuview` opens a menu of its children when tapped. Its label is a `title` with an optional `symbol`, or a `label` child. Inside, use `btn`, `toggle`, `picker`, `divider`, `sectionview` (to group items, with an optional `header`), and nested `menuview` elements for submenus. A `picker` in a menu shows its options in place, and `variant="menu"` turns it into a submenu. With an `onprimaryaction` handler, a tap runs that handler and a long press opens the menu.
- **Sliders and steppers.** A `slider` goes from `min` to `max`, which default to 0 and 1, and snaps to multiples of `step` when you set it. `oninput` fires while the user drags, and `onchange` fires when they let go. A `stepper` changes `value` by `step`, 1 by default, and stays between `min` and `max` if you set them.
- **Dates.** A `datepicker` takes a `Date` or an ISO 8601 string for `value`, `min`, and `max`, and `onchange` receives a `Date`. `components` is `date`, `time`, or `datetime`, the default. `variant` is `automatic`, `compact`, `graphical`, or `wheel`.
- **Progress.** A `progressview` shows a bar filled to `value` out of `max`, which defaults to 1, or a spinner when there's no `value`. Its children are its label.
- **Attribute values.** Attributes reach Swift as JSON, so `null`, booleans, numbers, strings, arrays, and objects keep their types, and functions are never sent. A `Date` becomes an ISO 8601 string, a `BigInt` becomes a number, a `Map` becomes an object, and a `Set` becomes an array. `NaN`, `Infinity`, and `undefined` inside arrays become `null`, and `undefined` properties are dropped. An attribute set to `null` or `undefined` is removed. Where an element expects a number, a numeric string like `spacing="8"` works too. Where it expects a string, a number or boolean is converted. Where it expects a boolean (like `checked` or `animated`), the values `false`, `0`, `null`, and `"false"` are false, and anything else, including the empty string of a bare attribute, is true.
- **Error boundaries.** `<svelte:boundary>` works as it does on the web. When a child throws while rendering or in an effect, the boundary's `failed` snippet renders in its place. That snippet uses the same elements as the rest of your app. Calling `reset` tries the children again. Errors that a boundary catches don't show the debug error overlay.
- **Names.** `txt`, `btn`, `sfsymbol`, `imageview`, `labelview`, `linkview`, `menuview`, `formview`, `sectionview`, `progressview`, `circleshape`, `ellipseshape`, and `pathshape` have these names because `text`, `button`, `image`, `symbol`, `label`, `link`, `menu`, `form`, `section`, `progress`, `circle`, `ellipse`, and `path` are already HTML and SVG elements in `svelte/elements`, and their types can't be overridden. Two prefixes are short for long words that come up often: `nav` for navigation, as in `navstack` and `navbarvisibility`, and `a11y` for accessibility, as in `a11ylabel`. Every other name spells its words out, as in `hittestable`.

## Rich text

A `txt` inside another `txt` styles part of the text, the way a `<span>` does. The spans join into one SwiftUI `Text`, so the text wraps as a whole, and each span keeps its own `font`, `weight`, `color`, and `background` on top of the styles around it:

```svelte
<txt color="secondary">
  The counter is at <txt weight="bold" color="primary">{count}</txt>. Read the
  <txt href="https://svelte.dev" underline>docs</txt>.
</txt>
```

To use a font that isn't a system style, set `fontname` to the font's PostScript name, such as `Georgia-Bold`. With `size`, the font has that fixed size. With `font` as well, the size scales with Dynamic Type relative to that text style. Spans take `fontname` too. A custom font must be listed under `UIAppFonts` in the app's Info.plist. If no installed font has the name, SwiftUI falls back to the system font.

A custom font can also list fallbacks with `fontfallbacks`, an array of PostScript names. They're tried in order for characters that the `fontname` font doesn't have. For example, `fontfallbacks={["GeezaPro"]}` covers Arabic text in a Latin font. Without a fallback, SwiftUI picks a system font for those characters.

Spans also take `italic`, `underline`, and `strikethrough`, and `href` turns a span into a link that opens in the browser. A span can turn a decoration back off with `underline={false}`.

For text from Markdown, set `markdown` to the source, or set it with no value to read the text inside the element:

```svelte
<txt
  markdown="Rendered by **[Svelte](https://svelte.dev)** as native _SwiftUI_."
/>
<txt markdown>Use `ref()` for **focus**.</txt>
```

Only inline Markdown works: bold, italic, strikethrough, code, and links. Headings, lists, and other blocks show up as plain text, and line breaks are kept. With `markdown`, nested `txt` elements are ignored.

Inside `txt`, the HTML inline tags style text the way a browser does by default. `strong` and `b` are bold, `em` and `i` are italic, `code` and `kbd` are monospaced, `del` and `s` are struck through, `ins` and `u` are underlined, `mark` is highlighted, `sub` and `sup` sit below and above the baseline, and `br` starts a new line. `a` with an `href` is a link, and `span` groups text without styling it. The block tags, such as `p`, `h1` to `h6`, `ul`, `ol`, `blockquote`, `pre`, and `table`, work outside `txt`. They're there mainly for Markdown, which is covered in [Libraries](libraries.md#mdsvex).

A `flowstack` lays its children out in rows and starts a new row when the next child doesn't fit, the way words wrap in a paragraph. Use it for tags, chips, and other items that have their own widths. Children keep their ideal size, so pair the flow with `fixedsize` on any child that shouldn't shrink. Set `spacing` for the gap between children in a row, `linespacing` for the gap between rows, and `alignment` to `center` or `trailing` to align each row.

A `reflowstack` puts its children in one row when their ideal widths fit, and stacks them in a column when they don't. Unlike `viewthatfits`, it lays out a single set of children, so an element inside it keeps its identity when the layout switches and can use a `matchedid` for a shared-element transition. In a column, each child gets at most the stack's width. Set `spacing` for the gap between children, and `alignment` for where they sit: its vertical part, such as `top`, applies to a row, and its horizontal part, such as `leading`, applies to a column. The default, `center`, centers children in both.

`baselineoffset` moves `txt` text up or down from the baseline in points, which is useful for footnote markers and fractions. `underlinestyle` (`solid`, `dotted`, or `dashed`) and `underlinecolor` change how an underline looks when `underline` is set. `monospaceddigit` gives the digits the same width, so a counter or a column of numbers doesn't shift as its value changes.

## Colors and shapes

`color`, `background`, `fill`, and `stroke` take any of these:

| Value                                           | Examples                                                                                                                              |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| A SwiftUI color                                 | `blue`, `pink`, `clear`, `accent`                                                                                                     |
| A UIKit system color, which adapts to dark mode | `systemBackground`, `secondaryLabel`, `separator`, `systemGray4`                                                                      |
| A CSS color                                     | `#ff3e00`, `#f008`, `rgb(255 62 0 / 50%)`, `hsl(14 100% 50%)`                                                                         |
| A hierarchical style                            | `primary`, `secondary`, `tertiary`, `quaternary`, `quinary`                                                                           |
| A material                                      | `ultraThinMaterial`, `thinMaterial`, `regularMaterial`, `thickMaterial`, `ultraThickMaterial`, `bar`                                  |
| A color's gradient                              | `blue.gradient`                                                                                                                       |
| A gradient object                               | `{ linear: ["red", "orange"], start: "topLeading", end: "bottomTrailing" }`, `{ radial: [...], endRadius: 80 }`, `{ angular: [...] }` |

Gradient colors can be plain colors, spaced evenly, or `{ color, location }` stops. `tint` and the colors of nested `txt` spans take colors only.

The shape elements draw SwiftUI shapes, filled with the foreground style unless you set `fill`, `stroke`, or both:

```svelte
<roundedrectangle
  cornerradius={12}
  fill="regularMaterial"
  stroke="separator"
  width={120}
  height={44}
/>
<circleshape stroke="teal" linewidth={3} dash={[5, 3]} width={40} height={40} />
<pathshape
  d="M12 12V2a10 10 0 1 1-10 10z"
  viewbox="0 0 24 24"
  fill="orange"
  width={40}
  height={40}
/>
```

`stroke` draws the outline centered on the shape's edge, so half of its width falls outside the frame. `strokeborder` draws the outline inside the edge, like SwiftUI's `strokeBorder`, which keeps it within the frame. Use `strokeborder` for panel borders and rings that must sit on exact pixels. `strokeborder` takes precedence when both are set.

| Element                                  | SwiftUI                        | Attributes                                                                    |
| ---------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------- |
| `rectangle`                              | `Rectangle`                    |                                                                               |
| `roundedrectangle`                       | `RoundedRectangle`             | `cornerradius`, `cornerstyle`                                                 |
| `unevenroundedrectangle`                 | `UnevenRoundedRectangle`       | `topleading`, `toptrailing`, `bottomleading`, `bottomtrailing`, `cornerstyle` |
| `circleshape`, `ellipseshape`, `capsule` | `Circle`, `Ellipse`, `Capsule` | `cornerstyle` (on `capsule`)                                                  |
| `pathshape`                              | A `Path` from SVG path data    | `d`, `viewbox`                                                                |

All of them also take `linewidth`, `linecap`, `linejoin`, `dash`, `dashphase`, and `fillrule` (`nonzero` or `evenodd`). `cornerstyle` is `continuous`, the default, or `circular`. A `pathshape` reads every SVG path command, including arcs. With a `viewbox`, it scales the path to fit its frame the way an SVG icon does; without one, it draws the path at its own coordinates.

`brightness`, `colormultiply`, `blendmode`, and `compositinggroup` change how an element's colors mix with what's behind it. `brightness` is a number from -1 to 1 that lightens or darkens the element. `colormultiply` multiplies the element's colors by a color, which tints it. `blendmode` takes one of the CSS blend mode names, such as `multiply`, `screen`, or `color-dodge`. Set `compositinggroup` to blend an element's children as one layer, so the blend mode and `opacity` apply to the group rather than to each child.

## Bindable components

Svelte doesn't allow `bind:` on elements in custom renderer components, so `swiftui-svelte/components` wraps the controls in components with bindable props:

```svelte
<script lang="ts">
  import { Sheet, Slider, TextField, Toggle } from "swiftui-svelte/components";

  let name = $state("");
  let volume = $state(0.5);
  let notify = $state(true);
  let editing = $state(false);
</script>

<TextField placeholder="Name" bind:value={name} />
<Slider bind:value={volume}><txt>Volume</txt></Slider>
<Toggle bind:checked={notify}><txt>Notifications</txt></Toggle>
<btn onclick={() => (editing = true)}>Edit</btn>
<Sheet bind:presented={editing}><txt>Editing {name}</txt></Sheet>
```

| Component            | Binds                                           | Element                     |
| -------------------- | ----------------------------------------------- | --------------------------- |
| `TextField`          | `value`                                         | `textfield`                 |
| `NumberField`        | `value`                                         | `textfield` with a `format` |
| `SecureField`        | `value`                                         | `securefield`               |
| `TextEditor`         | `value`                                         | `texteditor`                |
| `Toggle`             | `checked`                                       | `toggle`                    |
| `Picker`             | `value`                                         | `picker`                    |
| `MultiPicker`        | `value`                                         | `picker` with `multiple`    |
| `MultiDatePicker`    | `value`                                         | `multidatepicker`           |
| `ColorPicker`        | `value`                                         | `colorpicker`               |
| `Slider`             | `value`                                         | `slider`                    |
| `Stepper`            | `value`                                         | `stepper`                   |
| `DatePicker`         | `value`                                         | `datepicker`                |
| `DisclosureGroup`    | `expanded`                                      | `disclosuregroup`           |
| `TabView`            | `selection`                                     | `tabview`                   |
| `List`               | `selection`, `editing`                          | `list`                      |
| `MultiList`          | `selection`, `editing`                          | `list` with `multiple`      |
| `NavSplitView`       | `visibility`, `compactcolumn`                   | `navsplitview`              |
| `Searchable`         | `value`, `presented`, `tokens`, `selectedscope` | `searchable`                |
| `Sheet`              | `presented`                                     | `sheet`                     |
| `FullScreenCover`    | `presented`                                     | `fullscreencover`           |
| `Popover`            | `presented`                                     | `popover`                   |
| `Inspector`          | `presented`                                     | `inspector`                 |
| `ConfirmationDialog` | `presented`                                     | `confirmationdialog`        |
| `Alert`              | `presented`                                     | `alert`                     |

Each component takes the same attributes and events as its element, and still calls your handlers. To change a value on its way in, use a function binding: `bind:value={() => name, (value) => (name = value.slice(0, 12))}` limits a field to 12 characters, and the field shows the shortened text. The presentation components, from `Sheet` to `Alert`, show their content while `presented` is true, and set it to false when the user dismisses them.

## Element refs and focus

Svelte's compiler rejects `bind:this` in custom renderer components, so swiftui-svelte gives you `ref()` instead. A ref is an attachment: put it on an element with `{@attach}`, then call its methods to move focus, scroll, or measure:

```svelte
<script lang="ts">
  import { ref } from "swiftui-svelte";

  const field = ref();
  const rows = ref();
</script>

<list {@attach rows}>
  <textfield {@attach field} onsubmit={() => field.focus()} />
  <!-- rows -->
</list>
<btn onclick={() => rows.scrollTo("bottom")}>Jump to the end</btn>
```

| Method                                 | What it does                                                                                                                                                                                                                |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `focus()`, `blur()`                    | Moves keyboard focus to the element, or takes it away                                                                                                                                                                       |
| `scrollIntoView({ anchor, animated })` | Scrolls the nearest `scrollview` or `list` until the element is visible. `anchor` is `top`, `center`, `bottom`, `leading`, `trailing`, or a corner such as `topLeading`. Scrolling is animated unless `animated` is `false` |
| `scrollTo(edge, { animated })`         | On a `scrollview` or `list`, scrolls to its first child (`"top"`) or last child (`"bottom"`)                                                                                                                                |
| `scrollTo({ x, y }, { animated })`     | On a `scrollview` or `list`, scrolls to an offset in points from its top leading corner. Pass `x`, `y`, or both, and leave out the axis you don't need.                                                                     |
| `measure()`                            | Resolves to the element's `{ x, y, width, height }` in window coordinates, in points, once the element is on screen. It resolves to `null` if the element goes away first                                                   |

Calls made before the element reaches SwiftUI wait for it, so you can call `focus()` right after rendering a field. When the element is gone, calls do nothing.

`scrolldisabled` stops a `scrollview` or `list` from scrolling and keeps its content in place. `onscrollphase` reports what the scroll is doing, and `onscrollvisibility` reports when an element enters or leaves the visible part of its scroll view, so you can load more rows as they come into view. Set `visibilitythreshold` to require a larger part of the element to be on screen before it counts as visible.

For declarative focus, `textfield` takes a `focused` attribute and fires `onfocus` and `onblur`. The `TextField` component makes it bindable:

```svelte
<script lang="ts">
  import { TextField } from "swiftui-svelte/components";

  let name = $state("");
  let editing = $state(false);
</script>

<TextField bind:value={name} bind:focused={editing} />
{#if editing}
  <btn onclick={() => (editing = false)}>Done editing</btn>
{/if}
```

Pressing Return in a text field ends editing, as usual in SwiftUI. To keep the keyboard up for the next entry, call `focus()` in `onsubmit`.

## Transitions and animation

Svelte's `transition:`, `in:`, and `out:` directives need the DOM, so the compiler rejects them in custom renderer components. Use the `transition`, `in`, and `out` attributes instead. They work on any element and use SwiftUI's transitions:

```svelte
{#if saved}
  <txt transition="scale opacity" animation="bouncy">Saved!</txt>
{/if}

{#if open}
  <vstack
    in="move-top"
    out="opacity"
    animation={{ type: "easeOut", duration: 250 }}
  >
    <txt>Details</txt>
  </vstack>
{/if}
```

- `transition` plays when the element is added and when it's removed. `in` plays only when it's added, and `out` only when it's removed, the way Svelte's directives do.
- The names are `opacity` (or `fade`), `scale`, `slide`, `blur`, `move`, and `push`. `move` and `push` take an edge: `move-top`, `move-bottom`, `move-leading`, `move-trailing`, and the same for `push`. Without an edge, `move` comes from the bottom and `push` from the trailing edge. Separate names with spaces to combine them, as in `"scale opacity"`.
- `animation` sets the curve: `default`, `linear`, `easeIn`, `easeOut`, `easeInOut`, `spring`, `smooth`, `snappy`, or `bouncy`. For more control, pass an object. Its `type` is the curve, `duration` and `delay` are in milliseconds, and `bounce` goes from -1 to 1 for the spring curves. It also takes `speed`, `repeat` (a count, or `true` to repeat forever), and `autoreverses`.
- `animation` also sets the curve that `animated` uses when a container's children change.

To set your own easing, use `type: "timingCurve"` with `curve`, which takes the four control points of a cubic Bézier, as in CSS. `curve: [0.4, 0, 0.2, 1]` is the standard ease-in-out curve. The same object works for `animation`, `in`, `out`, and `withAnimation`. Set `disablesanimations` on an element to stop its changes from animating, including changes that a surrounding `withAnimation` makes.

A button can show feedback while it's pressed or while the pointer is over it. Set `pressed` or `hovered` on the `btn` to an object with any modifier, such as `background`, `radius`, `border`, `shadow`, `colormultiply`, `scale`, `opacity`, `brightness`, or `color`. Each value replaces the same attribute on the button's direct children while that state is active, and a value of `false` removes it, for example, `shadow: false` removes a child's shadow. Any element inside the button can also set its own `pressed` or `hovered`, which applies to that element alone while the button is in that state. For example, `<txt pressed={{ color: "red" }}>` changes the text's color while the button is pressed, and a `<background>` child can drop its shadow with `pressed={{ shadow: false }}`. An element's own values win over the button's. The state's `animation` plays when the state starts, and again when it ends unless the state that follows sets its own, so a press fades in and out on the same curve. Without `animation`, the change uses SwiftUI's default animation. The press state comes from the button style, so it does not wait for a message to go to Svelte and back. A button with feedback anywhere in its label uses this press styling in place of its `variant`, so draw its chrome with the label's own modifiers.

Two more modifiers cover effects that button feedback often needs. `insetshadow` draws a soft inner edge along the element's `clipshape`, or along the rounded corners set by `radius` when there is no `clipshape`, like an inset shadow. Set `opacity={0}` and `pressed={{ opacity: 1 }}` on the element to fade the edge in while the button is pressed. `lighten` brightens an element by blending a copy of it over itself with the plus-lighter mode, at the opacity that you give. For example, `hovered={{ lighten: 0.125 }}` lightens a row when the pointer is over it.

Shared-element transitions take two steps. Put `namespace` on a container, such as a `vstack`, and give the elements that trade places inside it the same `matchedid`. When one replaces the other in a state change wrapped in `withAnimation`, the element animates from its old frame to its new one. Use this to move a thumbnail into a detail view or a badge into a larger one.

### Animating a state change

To animate everything that one state change does to the screen, wrap the change in `withAnimation`, the way you would in SwiftUI:

```svelte
<script lang="ts">
  import { withAnimation } from "swiftui-svelte";

  let count = $state(0);
</script>

<btn onclick={() => withAnimation(() => count++, "bouncy")}>Add one</btn>
<progressview value={count} max={10} />
```

- `withAnimation` runs the callback, flushes the updates it causes right away, and sends them to SwiftUI inside an animation. Changed attributes, text, and added or removed elements all animate together. Updates that were already waiting go out first, without animation.
- The second argument takes the same values as the `animation` attribute. Leave it out for SwiftUI's default animation, or pass `false` to turn animations off for that change.
- It returns whatever the callback returns. Only changes made synchronously in the callback animate, so for async work, call `withAnimation` again once the data arrives.
- A `withAnimation` that runs while another one is applying its changes, for example from an `$effect` that the outer change triggers, waits until those changes have gone out. Its callback then runs with its own animation, the way an `onChange` animation in SwiftUI applies on top of the change that triggered it. The inner call returns `undefined`.
- Call it from event handlers, timers, and other callbacks, not from inside `$derived`.

## Header, footer, label, background, and overlay

Where SwiftUI takes a view builder, swiftui-svelte takes a child element with the builder's name. Its children become the view, so a header can hold a symbol, a badge can sit over an image, and a snippet can fill any of them:

```svelte
<script lang="ts">
  const avatar = "https://github.com/sveltejs.png";
</script>

{#snippet heading(text: string)}
  <hstack spacing={6}><sfsymbol name="iphone" /><txt>{text}</txt></hstack>
{/snippet}

<sectionview>
  <header>{@render heading("This device")}</header>
  <!-- rows -->
  <footer><txt>Updated just now</txt></footer>
</sectionview>

<asyncimage src={avatar} width={48} height={48}>
  <overlay alignment="bottomTrailing">
    <sfsymbol name="checkmark.seal.fill" label="Verified" />
  </overlay>
</asyncimage>
```

| Element                 | Goes inside   | SwiftUI                                                                                                                                                  |
| ----------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `header`, `footer`      | `sectionview` | `Section`'s `header` and `footer`                                                                                                                        |
| `label`                 | `picker`      | `Picker`'s `label`                                                                                                                                       |
| `background`, `overlay` | Any element   | `.background(alignment:)` and `.overlay(alignment:)`. `alignment` is `center` (the default), an edge such as `top`, or a corner such as `bottomTrailing` |

The slot elements aren't laid out with the other children. A `header` or `footer` element replaces the attribute of the same name, and `background` and `overlay` draw behind or in front of the element at its size.

A `label` element has no attributes of its own. Its children become the label, and a development build warns about any attribute you put on the `label` itself, so put modifiers on the elements inside it.

## Presentations, toolbars, and swipe actions

These elements aren't drawn where they appear. Instead, they attach to the element around them, the way their SwiftUI modifiers do:

- A `sheet`, `fullscreencover`, `alert`, or `inspector` is presented for as long as it's rendered, so you show and hide it with `{#if}`, or with the `Sheet`, `FullScreenCover`, `Alert`, and `Inspector` components and `bind:presented`. It can go anywhere in your markup, even inside a list row or a component: swiftui-svelte presents it from the nearest `screen`, `tab`, or presentation around it, or from the root of the app. When the user dismisses it, `ondismiss` fires so you can update your state. An `alert` uses its `txt` children as the message and its `btn` children as the actions.
- A `popover` or a `confirmationdialog` points at the element it's in, so put it inside the `btn` that opens it. The `Popover` and `ConfirmationDialog` components support `bind:presented`. A `confirmationdialog` works like an `alert`, and `titlevisibility="visible"` shows its `title`. On iPhone, a popover opens as a sheet unless you set `adaptation="popover"`. A popover is as wide as its content, so give long text a `width`.
- Sheets, popovers, and inspectors take `detents`, the heights the user can drag them to: `medium`, `large`, `{ fraction }` for a fraction of the screen, such as `{ fraction: 0.25 }`, or `{ points }` for a height in points, such as `{ points: 300 }`. `dragindicator="visible"` shows the handle, `dismissible={false}` keeps the user from swiping it away, `backgroundinteraction` lets the user keep using the screen behind it (`true`, or a detent such as `{ fraction: 0.25 }` to allow it only up to that height), and `cornerradius` rounds its corners. A `fullscreencover` covers the whole screen and never closes with a swipe.
- An `inspector` opens as a column beside the content on iPad and as a sheet on iPhone. Put it inside a `screen`, and set `columnwidth` to a width or to `{ min, ideal, max }`.
- A `screen` takes options for its bars. `subtitle` shows a line under the title on iOS 26, and `titledisplaymode` is `automatic`, `inline`, or `large`. `backbuttonhidden` hides the back button. `navbarvisibility` and `tabbarvisibility` take `visible`, `hidden`, or `automatic`, and `navbarbackground` fills the navigation bar with a color or a material.
- A `toolbar` inside a `screen` adds its children as toolbar items. Its `placement` picks where they go: `trailing` (the default), `leading`, `principal` (in place of the title), `bottom`, `keyboard`, or the semantic placements `primaryAction`, `secondaryAction` (in the More menu), `confirmationAction`, `cancellationAction`, `destructiveAction`, `navigation`, and `status`. A `toolbar` also works inside any other element, such as a dialog or a section of a page, and attaches to that element. For example, a `toolbar` with `placement="keyboard"` next to a `textfield` in a `vstack` shows its bar above the keyboard while the field has focus. A `menuview` in a toolbar opens as a menu. On iOS 26, a `toolbarspacer` between two toolbars with the same `placement` separates their items, with a fixed gap or with `variant="flexible"` to push them apart. On iOS 26 the floating tab bar covers the bottom bar, so set `tabbarvisibility="hidden"` on a screen that has a bottom toolbar.
- A `swipeactions` inside a list row adds its buttons as the row's swipe actions.
- A `contextmenu` inside any element opens its children as a menu when the user touches and holds the element (or right-clicks it on the Mac). It takes the same items as a `menuview`: buttons, toggles, pickers, dividers, sections, and nested menus. Add a `preview` child to show a custom view above the menu in place of the element itself.

```svelte
<script lang="ts">
  let items: Array<string> = $state(["Milk", "Eggs"]);
  let confirming = $state(false);
</script>

<navstack>
  <screen title="Groceries">
    <list>
      {#each items as item (item)}
        <txt>{item}</txt>
      {/each}
    </list>

    <toolbar>
      <btn onclick={() => (confirming = true)}>Clear</btn>
    </toolbar>

    {#if confirming}
      <alert title="Clear the list?" ondismiss={() => (confirming = false)}>
        <txt>This can't be undone.</txt>
        <btn role="cancel" onclick={() => (confirming = false)}>Cancel</btn>
        <btn role="destructive" onclick={() => (items = [])}>Clear</btn>
      </alert>
    {/if}
  </screen>
</navstack>
```

A sheet or full-screen cover can set its background with `presentationbackground`. It takes a color, material, or gradient. It also takes `clear` for no background, or `{ glass: "regular" }` for a Liquid Glass background. The glass variant `clear` is also available. Before iOS 26, the glass background falls back to a material. A sheet's detents can be a height in points, such as `detents={[320]}`, so a drawer can fit its content.

## Accessibility

Every element is a SwiftUI view, so VoiceOver, Voice Control, and Switch Control work without extra code. Controls read their own labels and values, and `sfsymbol` and `imageview` take a `label`. These attributes adjust what assistive technologies hear and do on any element:

| Attribute                                          | SwiftUI                                                                                                                                                                             |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `a11ylabel`, `a11yvalue`, `a11yhint`               | `.accessibilityLabel`, `.accessibilityValue`, and `.accessibilityHint`                                                                                                              |
| `a11yinputlabels`                                  | `.accessibilityInputLabels`: the names that Voice Control accepts for the element                                                                                                   |
| `a11ytraits`, `a11yremovetraits`                   | `.accessibilityAddTraits` and `.accessibilityRemoveTraits`, with names such as `button`, `header`, `selected`, or `toggle`                                                          |
| `a11yheading`                                      | `.accessibilityHeading`, with a level from `1` to `6`, or `true` for a heading without a level                                                                                      |
| `a11ysortpriority`                                 | `.accessibilitySortPriority`. VoiceOver visits elements with higher priorities first                                                                                                |
| `a11ychildren`                                     | `.accessibilityElement(children:)`. `combine` merges the children into one element, `contain` groups them under the element, and `ignore` hides them behind the element's own label |
| `a11yhidden`                                       | `.accessibilityHidden`                                                                                                                                                              |
| `a11yactions`, `ona11yaction(name)`                | `.accessibilityActions`: custom actions that VoiceOver lists in its Actions rotor                                                                                                   |
| `ona11yadjust(direction)`                          | `.accessibilityAdjustableAction`, where `direction` is `"increment"` or `"decrement"`                                                                                               |
| `ona11yactivate`, `ona11yescape`, `ona11ymagictap` | `.accessibilityAction` for the default action, the escape gesture, and the magic tap                                                                                                |
| `testid`                                           | `.accessibilityIdentifier`, for UI tests                                                                                                                                            |

This star rating reads as one adjustable element, so VoiceOver users swipe up or down to change it:

```svelte
<hstack
  a11ychildren="ignore"
  a11ylabel="Rating"
  a11yvalue="{rating} of 5 stars"
  ona11yadjust={(direction) => (rating += direction === "increment" ? 1 : -1)}
>
  {#each [1, 2, 3, 4, 5] as star (star)}
    <sfsymbol name={star <= rating ? "star.fill" : "star"} />
  {/each}
</hstack>
```

- `testid` on a container applies to every element inside it, as `accessibilityIdentifier` does in SwiftUI. To give the container its own identifier and keep the identifiers of its children, add `a11ychildren="contain"`.
- `announce(message)` from `swiftui-svelte/app` makes VoiceOver speak a message, such as "Saved" after a background save. Pass `{ priority: "high" }` so that other speech can't interrupt it, or `{ priority: "low" }` to wait until current speech ends.
- `env` reports whether VoiceOver or Switch Control is running and whether the user turned on the related display settings. See [Device environment](environment.md).
