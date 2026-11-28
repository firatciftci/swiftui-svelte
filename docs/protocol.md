# Host protocol

This document specifies what a host must implement to run a swiftui-svelte app. A host is the native side that loads a Svelte bundle into a JavaScript engine, provides the `__native*` globals, and renders the batches of changes that the bundle sends. The iOS host, which renders SwiftUI, is the reference implementation. A Jetpack Compose host is planned, and this document is written so that someone can build that host from the spec alone.

The words "must," "must not," "should," and "may" are normative. Where a statement describes SwiftUI behavior, a Compose host must emulate the observable effect or document why it cannot.

This is protocol version 3. Section 10 explains what the version means and when it changes.

## 1. Overview

A host provides a JavaScript engine that has no DOM, no `window`, and no Node APIs. The engine runs one bundle. The bundle calls globals that the host installs, and the host calls globals that the bundle installs.

There are four kinds of traffic:

1. **Render batches.** The bundle sends a flat JSON array of opcodes that describe a tree of native nodes. The host applies them in order and then renders. Section 3 defines them.
2. **Events.** The host sends an event for a node to the bundle, which runs the handlers attached to that node. Section 3.6 defines this.
3. **Invocations.** The bundle asks the host to do something to a node or to the app, such as focus a field or announce a message. Section 4 defines these.
4. **Requests.** The bundle asks the host for a service through a global, such as `fetch`, storage, or a native module. Sections 6 and 8 define these.

Everything crosses the boundary as strings, numbers, booleans, `null`, arrays, and objects that have been encoded as JSON. Binary data crosses as `Uint8Array` values, and only in the fetch, WebSocket, random, and digest globals.

The engine calls the host synchronously unless a section says otherwise. The host must not call into the engine from inside a call that the engine made to the host, except through the queued mechanisms that this document names.

## 2. Threading and the engine queue

The host should run the engine on one serial queue, separate from the UI thread. Every `__svelte*` global must be called on that queue. Every native UI mutation must happen on the UI thread.

The engine's queue must also run the work that the engine schedules for itself. JavaScriptCore, for example, runs garbage collection and `FinalizationRegistry` callbacks from the run loop of the thread that created it, so a host that uses JavaScriptCore runs the engine on a thread with a running run loop. The bundle drops the entry for a released node in a `FinalizationRegistry` callback, so if those callbacks never run, its node map grows for as long as the app runs.

The engine's microtask queue drains after each host call returns. A host must not assume that JavaScript work is finished when a call returns, because promises continue to run.

A render batch is applied on the UI thread, in order, before the host renders the next frame. If the host applies batches on a different thread from the one that runs the engine, it must copy the batch before it returns control to the engine. Batches, actions, and invocations arrive in one stream, and the host must handle them in the order the bundle sent them. A host call into the engine can produce new messages while the host is still handling an earlier one, for example when an action calls back into JavaScript. The host must queue those messages behind the ones it has not handled yet, and it must not apply them first.

## 3. Render protocol

### 3.1 Node model

The bundle builds a tree of nodes. There are three kinds:

- **Fragment.** A container with no native representation. The root of each mounted app is a fragment.
- **Element.** A named node with attributes and children. Its name is one of the element names in `src/elements.ts`, or the name of a registered native component (Section 6.3.3).
- **Text.** A string node. Comments are never sent to the host.

Every node has an integer ID. The bundle allocates IDs from a counter that starts at 1 and only increases, so within one engine instance an ID never names a different node. A node that the bundle removes and later inserts again keeps its ID (Section 3.4.2). The host must treat IDs as opaque keys. The host must not assume that IDs are dense or ordered.

An element or text node that the host has not received yet is "local" to the bundle. Once the host has received it, the node is "native." The bundle sends only changes to native nodes. A local node becomes native the first time it is inserted under a native parent.

### 3.2 Batches and commits

The bundle collects operations into one batch and sends it with `__nativeCommit(json)` or `__nativeCommit(json, animationJSON)`:

- `json` is a JSON array of tokens. Each operation is an opcode number followed by its operands, in the order that Section 3.4 gives. Node records are written inline as tokens, so the whole batch is one flat array.
- `animationJSON`, when present, is the JSON encoding of an animation option: `true`, `false`, a curve name, or an object. The host applies the batch with that animation. `false` means no animation. When the argument is absent, the host applies the batch without an animation transaction.

A batch is one transaction. The host must apply every operation in a batch before it renders the result. If a batch fails to decode, the host must reject the whole batch and must not apply a partial prefix. Section 3.7 describes the recovery requirement.

The bundle commits at most once per microtask, and it commits synchronously when an animated update runs. `__nativeCommit` returns nothing. Invocations (Section 4) that depend on the state a commit just applied are sent after that commit, so the host must apply a commit before it handles an invocation that arrived after it.

### 3.3 Name table

Attribute names and element names are sent once, as opcode 7 (`name`). The host assigns each name the next index, starting at 0, in the order it receives them. Later records refer to a name by its index.

The name table lasts for the lifetime of one engine instance. The host must not clear it between commits or between mounts. The host must clear it when it creates a new engine instance (for example, after a reload), because the bundle restarts its name table then.

If the host receives a name index that it has not assigned, it must treat the batch as malformed (Section 3.7).

### 3.4 Opcodes

Opcodes are integers. Each operation below starts with its opcode.

| Opcode | Name     | Operands, in order                      | Meaning                                |
| ------ | -------- | --------------------------------------- | -------------------------------------- |
| 0      | `root`   | fragment ID, protocol version, mount ID | Starts a mounted app.                  |
| 1      | `insert` | parent ID, before ID, node record       | Inserts a node under a parent.         |
| 2      | `move`   | parent ID, before ID, node ID           | Moves an existing native node.         |
| 3      | `remove` | node ID                                 | Removes a native node and its subtree. |
| 4      | `attr`   | node ID, name index, value              | Sets an attribute.                     |
| 5      | `unattr` | node ID, name index                     | Removes an attribute.                  |
| 6      | `text`   | text node ID, string                    | Changes the string of a text node.     |
| 7      | `name`   | name string                             | Adds the next entry to the name table. |

Rules that apply to all opcodes:

- The fragment ID in `root` is the root container for that mount. Inserts into that fragment use its ID as the parent ID.
- A before ID of 0 means "append at the end of the parent's children." A nonzero before ID names the sibling that the inserted or moved node must precede. The before ID is always a native node under the same parent.
- The host must ignore an operation that names an unknown node ID for `remove`, `attr`, `unattr`, and `text`. This is required because the bundle may send removals for nodes that were removed earlier in the same batch.
- The host must treat an insert or move whose parent ID is unknown as malformed.

#### 3.4.1 `root`

`root` carries the fragment ID of a mount, the protocol version that the bundle was built against, and the mount ID that the host passed to `__svelteMount`. The root record must come before any insert whose parent is that fragment, and it must be in the same batch or in an earlier one.

The host must check the protocol version before it applies any operation from the batch that carries the `root` record. If the version is not the one that the host implements, the host must apply nothing from that batch, including the `name` operations that come before the `root` record, and it must not render the mount. It must show the user an error that names both versions. A mismatch doesn't make the batch malformed, so the host doesn't remount (Section 3.7). The iOS host treats a mismatch as the state of the engine instance: every mount of that instance shows the error until a batch arrives whose `root` record names the host's protocol, or until the engine restarts. Section 10 covers this check.

#### 3.4.2 `insert`

The node record has one of two forms.

**Element record:**

```text
id, nameIndex, attributeCount, (nameIndex, value) × attributeCount, childCount, child record × childCount
```

`id` is a positive integer. Each child record has the same form as the node record, recursively.

**Text record:**

```text
-id, string
```

A text record starts with the negated node ID, followed by the string. The host must store the text node under the positive ID, which is the ID that `text` (opcode 6), `remove` (opcode 3), `move` (opcode 2), and before IDs use. The negative sign only tells the host that the record is a text node.

Each child record must be applied in order. An element record must register its own ID before the next sibling is read.

An insert of a node that the host already has must not create a second copy. The bundle sends `move` for nodes that already exist, so an insert of a node ID that is still in the tree is malformed. The bundle reuses the ID of a node that it removed and later inserts again, so an insert of an ID that an earlier `remove` freed, in the same batch or an earlier one, is valid.

#### 3.4.3 `move`

`move` reparents or reorders a native node. The node moves under `parent ID` and is placed before `before ID`, or at the end when `before ID` is 0. The move may cross parents. The host must update both the old and the new parent.

The bundle emits `move` for keyed reordering. Svelte's keyed `{#each}` blocks, and any other code that moves a native node, reach the host this way. The host must keep the node's subtree and its native state (for example, focus, scroll position, and text input) when it moves the node. A host that recreates a node on move violates this section.

#### 3.4.4 `remove`

`remove` deletes a native node and every descendant. The bundle sends one `remove` for the top node only. The host must release all descendants of that node, and it must not expect a separate `remove` for each descendant.

#### 3.4.5 `attr`, `unattr`, and value encoding

`attr` sets one attribute on a native node. `unattr` removes it. The bundle sends `unattr` when a value becomes undefined or is a function.

Attribute values are JSON values with these rules:

- **Strings, numbers, and booleans** are used as given.
- **Booleans follow HTML.** A bare attribute such as `<btn disabled>` arrives as the empty string, the same as `disabled=""` and `disabled={""}`, so where a host expects a boolean it must read the empty string as true. `false`, `0`, `null`, and the string `"false"` read as false, and every other value reads as true. Attributes that take either a flag or a value, such as `a11yheading` and `backgroundinteraction`, follow the same rule: the empty string means `true` and `"false"` means `false`.
- **`null` is absence.** A host must treat a JSON `null` value the same as `unattr`. The bundle does not use `null` to mean "set to nothing." The host must not store `null` as a present value. In an `insert` record, a `null` value declares an attribute instead: the element's markup sets the attribute from an expression whose value is `undefined` for now. A host can use a declaration to prepare for the attribute, for example to set up the modifiers it will need, so that a value that arrives later doesn't rebuild the element's native view.
- **Arrays and objects** are passed whole. Nested objects, such as a color stop list or a ShapeStyle, are encoded as JSON objects with the keys that `src/elements.ts` defines for that type. The host must not flatten them.
- **Functions are never sent.** Event handlers and actions are handled through `listens` and `actions` (Sections 3.6 and 6.3.3).
- **Map, Set, and BigInt values** are converted to objects, arrays, and numbers before encoding.

The bundle resolves the `class` attribute in its own code, and it sends the attributes that the class names produce as ordinary attributes. The host never receives `class` itself. An explicit attribute wins over a derived one with the same name.

The bundle sends `listens` as an array of event type names, as Section 3.6.1 describes. It is an attribute, so the host reads it like any other attribute.

#### 3.4.6 `text`

`text` changes the string of a native text node. The ID is the positive node ID. The host must update the displayed string in place and must not recreate the node.

#### 3.4.7 `name`

`name` adds one string to the name table (Section 3.3). It has no node ID.

### 3.5 Order of operations

Operations appear in a batch in the order the bundle produced them. A `name` entry always comes before the first operation that uses its index. Attribute and text updates for a node always follow the node's insert, if the insert is in the same batch. A node must be inserted before any `attr`, `unattr`, `text`, or `move` names it.

Invocations (Section 4) are sent as separate host calls, after the batch they depend on.

### 3.6 Events

The host sends events to the bundle with:

```text
__svelteDispatch(id, type, payload, request?)
```

- `id` is the native node ID.
- `type` is an event type string. The bundle runs the handlers it registered for that node and that type.
- `payload` is the event's JSON-compatible payload. It is `null` for events without a payload. Section 6.3.3 defines native-component payloads. Each built-in event's payload is defined by the element's JSDoc in `src/elements.ts`.
- `request` is an integer, and it appears only for events that expect a reply, such as `task` and `refresh`.

The payloads for the built-in event types that the iOS host sends are in this table. For any event that is not listed, the payload is `null`.

| Type                                | Payload                                                                               | Notes                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `tap`, `longpress`, `primaryaction` | `null`                                                                                |                                                        |
| `appear`, `disappear`               | `null`                                                                                |                                                        |
| `focus`, `blur`                     | `null`                                                                                |                                                        |
| `scroll`                            | `{ "x", "y", "width", "height", "contentWidth", "contentHeight" }` in points          | Rounded to two decimals.                               |
| `scrollphase`                       | `{ "phase": "idle" \| "tracking" \| "interacting" \| "decelerating" \| "animating" }` |                                                        |
| `scrollvisibility`                  | `{ "visible": boolean }`                                                              | The threshold comes from `visibilitythreshold`.        |
| `resize`                            | `{ "width", "height" }` in points                                                     |                                                        |
| `pop`                               | integer count of popped path entries                                                  |                                                        |
| `refresh`                           | `null`                                                                                | Carries a request.                                     |
| `task`                              | `null`                                                                                | Carries a request. The bundle passes an `AbortSignal`. |
| `taskcancel`                        | the request number, in the payload position                                           | Aborts the task or refresh with that request.          |
| `click`                             | `null`                                                                                |                                                        |
| `submit`                            | `null`                                                                                |                                                        |
| `change`, `input`                   | the new value                                                                         | Text and control value changes.                        |
| `load`, `error`                     | element-specific                                                                      | Image load results.                                    |

A host must not send `input` while an input method is composing text in the field (marked text). It sends `input` once the composition ends, with the field's full text, so that a handler that transforms the value never sees or replaces text that the user hasn't confirmed.

The bundle also has a `hover` event with the payload that its element documents, and two application events that are not element events (`memorywarning` and `openurl`, Section 5).

#### 3.6.1 `listens`

The bundle sends the `listens` attribute on each element. Its value is an array of the event types that the element has listeners for, limited to the types the bundle observes. The host should send an event only if its type is in that list, because the bundle drops events it has no handlers for.

The following types may be sent even when they are not in `listens`: `click`, `focus`, `blur`, `pop`, `change`, `input`, `submit`, `load`, and `error`. A host must not send any other event type that is not in `listens`.

#### 3.6.2 Requests and replies

Some events carry a `request` integer. The bundle runs its handlers and waits for them to finish. When they settle, the bundle sends `settled` as an invocation with `{ "request": n }` (Section 4). If no handler is registered, or if the bundle has already removed the node, the bundle sends `settled` right away.

The bundle drops an event for a node that it has removed, even when the host hasn't applied the `remove` yet. The node's handlers don't run, so a host can send events until the batch with the `remove` arrives.

The host must keep the request ID until it receives `settled` for it. For `refresh` and `task`, the host must wait for `settled` before it finishes the native operation (for example, before it ends a pull-to-refresh spinner).

`taskcancel` aborts the `AbortSignal` that a `task` or `refresh` handler received. The host sends it when it ends the operation early, such as when the view that owns a task disappears or its `taskid` changes, or when SwiftUI cancels a refresh because the list went away. The payload is the request number that the operation was started with. The host doesn't wait for `settled` after it sends `taskcancel`.

#### 3.6.3 Errors in handlers

If a handler throws, the bundle still runs the event's other handlers, and it rethrows the error from a timer with a delay of 0. For an event that carries a request, the bundle also waits for the promise that each handler returns, rethrows each rejection the same way, and then sends `settled` (Section 3.6.2). It doesn't rethrow a rejection from a `task` or `refresh` handler whose signal the host aborted with `taskcancel`. After an `input` or `change` event, the bundle resends the controlled value even when a handler failed, so the control shows the value from the app's state.

The host receives a rethrown error as an uncaught exception in the engine, the same as any other error that escapes a timer callback. The host must log it, and it should show it in its development UI. The host must not treat a handler error as a failed event or a malformed batch, must not remount because of it, and must keep delivering events.

### 3.7 Malformed batches and recovery

A host must check every batch before it applies any operation, or it must apply operations in a transaction that can be rolled back. A host that applies a partial batch leaves the name table and the node tree out of step with the bundle. Each of the following makes a batch malformed: an unknown opcode, a JSON syntax error, an operand of the wrong type, an unknown name index, an element record with ID 0, an insert or move into an unknown parent, an insert of a node ID that is still in the tree, and a move of a node into its own subtree. On a malformed batch, the host must apply none of its operations, including its `name` operations, and it must log the error. The host must then remount the app once, as a new engine instance, which resets the name table (Section 3.3). If the remounted app sends another malformed batch before it has applied a clean batch that it sent after mounting, the host must stop the engine, keep showing the error, and not apply further batches until the app restarts or the bundle changes. Once the remounted app applies such a clean batch, it has recovered, and a later malformed batch starts a new remount. The host should show the error in its development UI, and it should log it in release builds.

### 3.8 Mounts

The host starts a mount with:

```text
__svelteMount(mountId, name, json)
```

- `mountId` is an integer that the host chooses and keeps. Each mount has its own ID.
- `name` is the name of a component that the bundle registered through `mountApp`. An unknown name throws an `Error` in the engine. The host must treat that as a failed mount: it must log the message and show an error in place of the view, in release builds too.
- `json` is `{ "props": {...}, "actions": [...] }`. Props are the initial prop values. Each entry in `actions` is a prop name whose value is a function that the bundle calls back into the host with `__nativeAction` (Section 6.3.3).

The bundle sends `root` (opcode 0) before it mounts the component, so the host receives the root record first.

A host must not show a loading state forever. If the bundle has loaded and no `root` record for a mount arrives within two seconds, the host must show an error in place of the view that names the bundle's release and protocol (Section 10.3) and the host's own release and protocol.

The host updates props with:

```text
__svelteProps(mountId, json, actions?)
```

`json` is an object of the complete prop set, minus actions. Props missing from the object are removed. `actions` is optional. When the host passes it, it's a JSON array of the action names the mount has now: the bundle adds a function prop for each new name and removes the props of names that are gone. When the host leaves it out, the actions stay as they are. A host sends `actions` only when the set of names changes, and it may send it with the same props.

The host unmounts with:

```text
__svelteUnmount(mountId)
```

After this call the bundle sends `remove` for the mount's fragment. The host must release everything under that mount. Calls for an unknown mount ID are no-ops.

### 3.9 Node ID lifetime

The host must free its native state for a node when it receives `remove` for the node or for an ancestor of it. A freed ID never names a different node later, but the bundle can insert the same node again under its old ID (Section 3.4.2). The host must accept that insert and build the node from its record, without any state left from before the `remove`.

The bundle keeps its own map from ID to node for routing events, and that map is internal to the bundle. The host never needs to tell the bundle that a node is gone, because the bundle sends `remove` itself.

### 3.10 Animation transactions

When a batch carries an animation (Section 3.2), the host must apply the batch's changes inside an animation transaction with the given curve. A batch with `false` must apply without animation. A batch without an animation argument must apply without an animation transaction. The bundle sends animated batches only when the app asks for an animated state change.

SwiftUI uses `withAnimation` and transactions for this. A Compose host should use its own animation specs with equivalent duration and easing.

## 4. Invocations

The bundle calls the host with:

```text
__nativeInvoke(id, method, json)
```

- `id` is the native node ID, or `0` when the method applies to the app as a whole.
- `method` is the method name.
- `json` is a JSON object of options. An empty object is `{}`.

The bundle never sends an invocation to a node that is not yet native. An invocation for a node that the host has removed must be ignored. A method that the host does not implement must be ignored, and the host must log it once at the warning level. A `measure` request must always receive a reply (Section 4.4), even if the host cannot find the node.

### 4.1 Methods

| Method           | ID   | Options                                                                                                         | Reply                                                                                |
| ---------------- | ---- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `focus`          | node | `{}`                                                                                                            | None.                                                                                |
| `blur`           | node | `{}`                                                                                                            | None.                                                                                |
| `scrollIntoView` | node | `{ "anchor"?: anchor, "animated"?: boolean }`                                                                   | None.                                                                                |
| `scrollTo`       | node | `{ "edge": "top" \| "bottom", "animated"?: boolean }` or `{ "x"?: number, "y"?: number, "animated"?: boolean }` | None.                                                                                |
| `measure`        | node | `{ "request": n }`                                                                                              | `__svelteReply(n, rect \| null)`                                                     |
| `settled`        | node | `{ "request": n }`                                                                                              | None. The bundle sends this to report that the handlers for a request have finished. |
| `announce`       | `0`  | `{ "message": string, "priority": "low" \| "default" \| "high" }`                                               | None.                                                                                |
| `colorScheme`    | `0`  | `{ "value": "light" \| "dark" \| other }`                                                                       | None.                                                                                |

### 4.2 Focus

`focus` makes the node the first responder for keyboard input and focus rings. `blur` removes focus from it. If the node cannot take focus, the call does nothing. Focus changes that the user causes must be reported to the bundle as `focus` and `blur` events (Section 3.6).

### 4.3 Scrolling

`scrollIntoView` scrolls the nearest scroll container so that the node is visible. `anchor` chooses which part of the node aligns with the container. The anchor values are: `top`, `center`, `bottom`, `leading`, `trailing`, `topLeading`, `topTrailing`, `bottomLeading`, and `bottomTrailing`. `animated` defaults to `true`.

`scrollTo` with `edge` scrolls the container to its top or bottom. With `x` or `y`, it scrolls to that content offset in points. An offset that is missing keeps its current value. A Compose host must implement the same anchor values. An anchor that a host cannot express precisely should map to the nearest supported alignment.

### 4.4 Measuring

`measure` reports the node's frame in points, relative to the top-left of the mounted app's root container, as `{ "x", "y", "width", "height" }`. If the node is not laid out yet, the host must wait until it is. A frame with a zero width or a zero height does not count as laid out, so the host keeps waiting for a later frame. If the node is removed before it is laid out, or it never becomes visible, the host must reply `null` no later than when it removes the node.

The bundle waits for the reply, so a host must not leave a `measure` request without a reply. The host delivers each reply by calling `__svelteReply(request, rect)` on the engine queue.

### 4.5 Announce

`announce` posts a message for assistive technology to read aloud. `priority` is `low`, `default`, or `high`. `high` should interrupt the current speech. A host that has no assistive technology may ignore the call. The bundle never sends an empty or whitespace-only message.

### 4.6 Color scheme

`colorScheme` sets the app's appearance override. `value` is `"light"` or `"dark"`. Any other value means "follow the system." The bundle sends this when the user changes the app's own color-scheme preference. The host must report the resulting effective scheme through the environment (Section 7.1).

## 5. App lifecycle and URL events

The host delivers app-level events with:

```text
__svelteAppEvent(type, payload)
```

| Type            | Payload      | Meaning                                                                                |
| --------------- | ------------ | -------------------------------------------------------------------------------------- |
| `memorywarning` | `null`       | The system reports low memory. The bundle runs its memory-warning listeners. iOS only. |
| `openurl`       | a string URL | The app was asked to open a URL.                                                       |

The bundle does not receive scene phase changes through this call. Scene phase arrives in the environment snapshot (Section 7), and the bundle derives `active`, `inactive`, and `background` transitions from it.

### 5.1 URL opening

The host sends `openurl` for every URL that the app receives, including launch URLs and URLs that arrive while the app runs. The host must send the absolute string of each URL. The bundle parses it with `URL.canParse`, and it drops a string that does not parse.

If the bundle has no `onOpenURL` listener when the URL arrives, the bundle queues the URL and delivers it when the first listener subscribes. The host must not assume the URL was handled. The host must also deliver URLs that arrive before the bundle has loaded, once the bundle has loaded. A remote bundle that is still downloading must not drop pending URLs.

## 6. Native modules and components

### 6.1 Calling a module method

The bundle calls a native module method with:

```text
__nativeCall(id, module, method, argsJSON)
```

- `id` is an integer that the bundle chooses and that is unique among pending calls.
- `module` and `method` are strings. Names are case-sensitive.
- `argsJSON` is a JSON array of positional arguments.

The call is asynchronous. The host replies with:

```text
__svelteNativeReply(id, errorJSON | null, resultJSON | null)
```

- On success, `errorJSON` is `null` and `resultJSON` is the JSON-encoded result. A method with no result replies with `resultJSON` set to `null`.
- On failure, `errorJSON` is a JSON object `{ "code": string, "message": string }`, and `resultJSON` is `null`.

The bundle maps a missing `code` to `"native"`. A reply for an ID that the bundle no longer has pending is ignored.

The host must reply to every call, including calls to unknown modules and unknown methods. The host must not hold a reply longer than the native work takes to finish.

### 6.2 Error codes

| Code               | Meaning                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `invalidArguments` | The argument list did not match the method, or a URL used a scheme that `links` does not allow.                    |
| `invalidPath`      | A file path was empty or outside the app's file root.                                                              |
| `keychain`         | A secure storage operation failed.                                                                                 |
| `unknownModule`    | The module is not registered.                                                                                      |
| `unknownFunction`  | The module is registered, but the method is not.                                                                   |
| `native`           | Any other failure. This is the default.                                                                            |
| `unavailable`      | The bundle has no host (`__nativeCall` is missing). The bundle produces this itself. The host must not produce it. |

### 6.3 Module events and native components

Native modules can send events to the bundle with:

```text
__svelteNativeEvent(module, event, json | null)
```

The bundle delivers the decoded payload to listeners that subscribed to `module` and `event`. No built-in module emits events today.

#### 6.3.1 Built-in modules

The host must provide these modules and methods. Argument order matches the bundle.

| Module          | Method         | Arguments                                                                                 | Result                |
| --------------- | -------------- | ----------------------------------------------------------------------------------------- | --------------------- |
| `haptics`       | `impact`       | `{ "style"?: "light" \| "medium" \| "heavy" \| "soft" \| "rigid", "intensity"?: number }` | `null`                |
| `haptics`       | `notification` | `"success" \| "warning" \| "error"`                                                       | `null`                |
| `haptics`       | `selection`    | none                                                                                      | `null`                |
| `clipboard`     | `readText`     | none                                                                                      | string or `null`      |
| `clipboard`     | `writeText`    | string                                                                                    | `null`                |
| `clipboard`     | `hasText`      | none                                                                                      | boolean               |
| `share`         | `share`        | `{ "text"?, "url"?, "subject"? }`                                                         | boolean (`completed`) |
| `links`         | `open`         | URL string                                                                                | boolean               |
| `links`         | `canOpen`      | URL string                                                                                | boolean               |
| `secureStorage` | `get`          | key                                                                                       | string or `null`      |
| `secureStorage` | `set`          | key, value                                                                                | `null`                |
| `secureStorage` | `delete`       | key                                                                                       | `null`                |
| `files`         | `readText`     | path                                                                                      | string or `null`      |
| `files`         | `writeText`    | path, text                                                                                | `null`                |
| `files`         | `delete`       | path                                                                                      | `null`                |
| `files`         | `exists`       | path                                                                                      | boolean               |
| `files`         | `list`         | path (optional; empty or absent lists the file root)                                      | array of strings      |

The `haptics` styles and notification types are named after UIKit feedback generators. A host that cannot produce a given style should use the nearest feedback it has. File paths are relative to the app's own file root. A host must reject any path that leaves that root, and an empty path given to a method that needs a file, with `invalidPath`. Listing with an empty or absent path lists the file root. `links.open` and `links.canOpen` must allow only `http`, `https`, `mailto`, and `tel` URLs, compared case-insensitively on the scheme. Any other URL, including `file:` URLs, must be refused with `invalidArguments`. `share` must report `completed` as `true` only when the user finished the share. A host that cannot tell whether the user finished must say so in its documentation.

#### 6.3.2 Custom native modules

A host may register more modules by name. A custom module must not reuse the name of a built-in module, because the built-in would be shadowed. A host should refuse such a registration and log an error instead.

#### 6.3.3 Native components

A native component is a host view that the bundle can use as an element. The host registers it by element name, with its attributes and events:

- **Name.** The element name is used in the bundle's markup. It must not be a name that the element vocabulary defines, because those names take precedence. A host that registers a conflicting name must refuse the registration and log an error.
- **Attributes.** The host receives every attribute the bundle sends for the element, as `attr` and `unattr` operations (Section 3.4.5), including `listens`. The component declares which attribute names are its own properties. The rest of the host does not interpret them.
- **Events.** The host sends events to the bundle with `__svelteDispatch`, using the event name that the component declares. Payloads are JSON values that the component encodes. The bundle's `on<name>` handler receives the payload.
- **Actions.** Props listed in the mount's `actions` array become functions on the bundle side. Calling one sends `__nativeAction(mountId, name, json)` to the host, with the payload as JSON. The host dispatches it to the component that owns the mount.

The bundle's type for a native component is `NativeElement<Attributes, Events>` in `src/elements.ts`. The bundle has no runtime registration for native components, so the host alone decides which names are native.

Reserved names: `listens` is owned by the bundle, so a component must not define its own `listens` attribute. `class` is never sent to the host, and `ref` is never sent as an attribute.

## 7. Environment

### 7.1 Snapshot fields

The host sends environment values as a JSON object with some or all of these fields. Each field has the type and units below. A field that is missing keeps its previous value, or the bundle's default if the host has never sent it. Values are in points when the field refers to a length.

| Field                       | Type                                         | Units or values                                              | Notes                                                          |
| --------------------------- | -------------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------- |
| `colorScheme`               | `"light" \| "dark"`                          |                                                              | Effective app appearance.                                      |
| `systemColorScheme`         | `"light" \| "dark"`                          |                                                              | System appearance.                                             |
| `liquidGlass`               | boolean                                      |                                                              | Whether the host renders the glass material. iOS 26 and later. |
| `reduceMotion`              | boolean                                      |                                                              |                                                                |
| `reduceTransparency`        | boolean                                      |                                                              |                                                                |
| `increaseContrast`          | boolean                                      |                                                              |                                                                |
| `voiceOver`                 | boolean                                      |                                                              |                                                                |
| `switchControl`             | boolean                                      |                                                              |                                                                |
| `differentiateWithoutColor` | boolean                                      |                                                              |                                                                |
| `invertColors`              | boolean                                      |                                                              |                                                                |
| `boldText`                  | boolean                                      |                                                              |                                                                |
| `buttonShapes`              | boolean                                      |                                                              | iOS accessibility setting.                                     |
| `dynamicTypeSize`           | string                                       | `xSmall` through `accessibility5`                            | Unknown values map to `large`.                                 |
| `locale`                    | string                                       | BCP 47 tag                                                   |                                                                |
| `languages`                 | array of strings                             | BCP 47 tags, most preferred first                            |                                                                |
| `timeZone`                  | string                                       | IANA identifier                                              |                                                                |
| `layoutDirection`           | `"leftToRight" \| "rightToLeft"`             |                                                              |                                                                |
| `horizontalSizeClass`       | `"compact" \| "regular" \| null`             |                                                              | `null` on platforms that have no size classes.                 |
| `verticalSizeClass`         | `"compact" \| "regular" \| null`             |                                                              | Same as above.                                                 |
| `scenePhase`                | `"active" \| "inactive" \| "background"`     |                                                              |                                                                |
| `safeAreaInsets`            | `{ "top", "leading", "bottom", "trailing" }` | points                                                       |                                                                |
| `keyboardHeight`            | number                                       | points                                                       | `0` when the keyboard is hidden.                               |
| `viewportWidth`             | number                                       | points                                                       | Usable width of the app's root container.                      |
| `viewportHeight`            | number                                       | points                                                       | Usable height of the app's root container.                     |
| `pixelRatio`                | number                                       | device pixels per point                                      |                                                                |
| `fontScale`                 | number                                       | multiplier, `1` at the default text size                     |                                                                |
| `platform`                  | string                                       | `"ios"`, `"macos"`, `"android"`, or another stable host name | Used by class conditions.                                      |
| `idiom`                     | string                                       | `"phone"`, `"pad"`, `"tv"`, or another stable host name      |                                                                |
| `onLine`                    | boolean                                      |                                                              | Network reachability.                                          |
| `userAgent`                 | string                                       | free text                                                    |                                                                |

The bundle's defaults are `colorScheme` `"light"`, `scenePhase` `"active"`, `dynamicTypeSize` `"large"`, `pixelRatio` `1`, `fontScale` `1`, and `onLine` `true`. Viewport sizes default to `0` until the host reports them.

### 7.2 Delivery

The host sends the whole snapshot once, before it mounts the first component. It provides the JSON through `__nativeEnvironment()`, a call that the bundle makes when it installs. If the JSON is invalid, the bundle must keep its defaults. A host must always send valid JSON.

After that, the host sends changes with:

```text
__svelteEnvironment(json)
```

`json` contains only the fields that changed, as a partial object. The bundle merges the partial object into its environment, so a host can send one field at a time.

The host must resend a field whenever the value it reports changes, for any reason. The causes include: the user changes a system setting; the device rotates or the window resizes; the keyboard shows or hides; the scene phase changes; the network reachability changes; the locale or time zone changes; or the host's own color-scheme override changes. The host must send viewport sizes and safe-area insets after each layout change. It may send them together with other changes in one call.

The bundle reads a field through the `env` object (`src/env.ts`). Each read subscribes to the field, and the bundle re-renders the reader when its value changes.

### 7.3 Classes and media queries

The bundle resolves Tailwind-style class conditions against this environment. It reads `colorScheme`, `viewportWidth`, `viewportHeight`, `reduceMotion`, `layoutDirection`, `increaseContrast`, `safeAreaInsets`, `pixelRatio`, `fontScale`, `platform`, and `idiom`. A change to any of those fields re-resolves the affected classes, so a host should send them as they change, not once at startup.

## 8. Web API shims

The bundle provides web-compatible globals and implements them with the host calls below. The host is responsible for backing each call.

### 8.1 Fetch

Fetch uses one call and a cancel call:

```text
__nativeFetch(id, requestJSON, body | null, onResponse, onData, onEnd)
__nativeFetchCancel(id)
```

`requestJSON` is `{ "url", "method", "headers", "redirect", "credentials", "cache" }`.

- `url` is an absolute `http`, `https`, or `file` URL.
- `method` is the request method, as the bundle normalizes it.
- `headers` is an array of `[lowercased name, value]` pairs. Repeated names are joined with `", "`, except `set-cookie`, which stays separate.
- `redirect` is `"follow"`, `"error"`, or `"manual"`. Under `"manual"`, the host does not follow the redirect, and it answers with an opaque redirect response, as described below.
- `credentials` is `"omit"`, `"same-origin"`, or `"include"`. It controls whether the host sends cookies with the request and stores the cookies that the response sets. Under `"include"`, the host always does. Under `"omit"`, it never does. Under `"same-origin"`, it does only when the request's origin is the app's origin. The host must check each redirect again against the same rule.
- `cache` is one of the fetch cache modes that the host understands.

The app's origin is the origin of the bundle's source URL when the host loads the bundle over `http` or `https`, such as from a dev server or a remote bundle. A bundle that the host loads from a file has no origin, and then `"same-origin"` never matches, so only `"include"` sends cookies. Two origins match when their schemes, hosts, and ports are equal, with the default port for the scheme when the URL has none.

`body` is the full request body as bytes, or `null`. The bundle buffers streamed bodies before the call, so the host never receives a stream.

The host calls the callbacks in this order:

1. `onResponse(metaJSON)` once, with `{ "status", "url", "redirected", "headers", "type"? }`. `headers` is an array of `[name, value]` pairs. Under `redirect: "manual"`, the status is `0` and the type is `opaqueredirect`, as it is on the web.
2. `onData(bytes)` zero or more times, with raw `Uint8Array` chunks. A host must not send empty chunks, and it may send chunks of any size.
3. `onEnd(null)` once on success, or `onEnd({ "message", "code"?, "name"? })` once on failure.

After `onEnd`, the host must not call any callback for that ID. On success, the host must call `onResponse` before `onEnd`. If the request fails before the host has a response, the host calls `onEnd` with the failure and no response.

`__nativeFetchCancel(id)` stops the request. The bundle calls it when the caller aborts the `AbortSignal` or cancels the response body. After a cancel, the host must not call `onData` for that ID. It may call `onEnd` with a failure, and the bundle ignores any call that arrives after the request has settled.

Failures reach the caller as a `TypeError` with the message `fetch failed`. The bundle rejects schemes other than `http`, `https`, `file`, and `data` before any host call, and it decodes `data:` URLs itself.

Fetch has no backpressure. A host that cannot keep up with `onData` must buffer or fail the request. A future protocol version may add pause and resume.

### 8.2 Streams and blobs

Response bodies are byte streams fed by `onData`. Request bodies are read to completion in the bundle before the call. Blobs and files live only in the bundle, and the host never receives a blob handle. Bytes cross the boundary only in `__nativeFetch` and the WebSocket send call.

### 8.3 WebSocket

```text
__nativeWebSocketOpen(id, url, protocolsJSON, handlers)
__nativeWebSocketSend(id, data)
__nativeWebSocketClose(id, code, reason)
```

- `url` is an absolute `ws` or `wss` URL. The bundle maps `http` and `https` to `ws` and `wss`.
- `protocolsJSON` is a JSON array of subprotocol names.
- `handlers` is an object of functions that the host calls back: `open(protocol)`, `message(data)`, `sent(byteCount)`, `close(code, reason, wasClean)`, and `error(message)`.
- `data` in the send call is a UTF-8 string for a text frame, or a `Uint8Array` for a binary frame.
  `__nativeWebSocketClose(id, code, reason)` takes `code` as a close code or `null`. The bundle accepts `1000` or a number from `3000` to `4999`. When the caller gives no code, the bundle sends `null`, and the host must send close status `1000` on the wire. When the peer sends no status code, the host must report `1005` in the `close` callback. A host that cannot send a code from `3000` to `4999` must send `1000` instead. If the bundle closes a socket that is still connecting, the host must abandon the connection. The bundle then reports the failure itself with `error` and `close` with code `1006`.

The host must call `open` once the socket is connected, with the negotiated subprotocol or an empty string. It must call `message` for each received frame, `sent` after each send completes, and `close` once when the socket closes, with `wasClean` set as the WebSocket specification defines. A failed connection is reported through `error` and then `close` with code `1006`.

The host must not deliver `message` events after `close`. Send calls on a socket that is not open must be ignored.

### 8.4 EventSource

EventSource runs on the fetch call, with `Accept: text/event-stream` and `Cache-Control: no-cache`. The host has no separate EventSource call. A response whose status is not `200`, or whose content type is not `text/event-stream`, fails the connection without retrying. A stream that ends or errors reconnects after the `retry` delay (3000 milliseconds by default), with `Last-Event-ID` set.

### 8.5 Crypto

- `__nativeRandomFill(bytes)` fills a `Uint8Array` in place with cryptographically secure random bytes. It must fill at most 65,536 bytes per call. If the platform's random source fails, the host must report the failure as an error, not fill zeros. The bundle's `crypto.getRandomValues` then throws.
- `__nativeDigest(algorithm, bytes)` returns a `Uint8Array` digest for `"SHA-1"`, `"SHA-256"`, `"SHA-384"`, or `"SHA-512"`. Any other algorithm must throw.

The bundle installs `crypto` only when both `__nativeRandomFill` and `__nativeDigest` are present. `crypto.subtle` exposes `digest` only. The bundle throws a `TypeError` for input that is not a typed array.

### 8.6 Storage

`localStorage` is a string-valued map, held in memory and persisted by the host:

- `__nativeStorageLoad()` returns a JSON object of all saved string pairs. The bundle reads it once when it installs. An empty or missing value means no saved entries.
- `__nativeStorageSave(json)` receives the complete map as a JSON object after each change. The bundle batches changes into one save per microtask.

The host must store the map durably, in a location the app can read on its next launch. The bundle sends the complete map on every save, but several engines can share one store, for example two windows of the same app. So the host must write only the entries that changed since this engine's last load or save, and it must keep entries that other engines wrote. The host must not share storage between apps.

The bundle limits each storage to 5 MB, counted as the length of every key and value in UTF-16 code units. A `setItem` that would go over the limit throws a `DOMException` named `QuotaExceededError` and leaves the storage unchanged.

`sessionStorage` is in memory only, and it starts empty at each engine start.

A value that is not valid JSON, or that is not a JSON object of strings, is treated as empty.

App state restoration uses `localStorage`. Each restorable value is stored under the key prefix `swiftui-svelte.restorable.`, as JSON. A host gets no separate restoration call.

### 8.7 Timers and clocks

The host provides `setTimeout`, `setInterval`, `clearTimeout`, and `clearInterval`. Each timer ID is an integer. Delays are milliseconds. A host must clamp a delay larger than the maximum signed 32-bit integer to that maximum, and it must run intervals no more often than once per millisecond. Clearing an unknown ID is a no-op.

The host provides `__nativeNow()`, a monotonic clock in milliseconds. The bundle calls it on the engine queue, and it must be monotonic. `performance.now()` is that clock minus its origin. `performance.timeOrigin` is the wall-clock time at engine start.

`requestAnimationFrame` is built on the host's display link. The host calls `__nativeRequestFrame()` when the bundle needs a frame, and the host must call `__svelteFrame(time)` at most once for each display refresh that follows that request. `time` is `__nativeNow()` at the frame, in milliseconds.

### 8.8 Logging

The bundle redirects `console.log`, `console.info`, `console.warn`, `console.error`, and `console.debug` to `__nativeLog(level, message)`. `level` is one of those five names. `message` is the arguments joined with spaces, with objects encoded as JSON and errors as their stacks. A host must show these messages in its development log.

In development builds, the bundle also sends its own warnings, such as an attribute name it doesn't recognize, to `__nativeDiagnostic(json)` when the host defines that function, and to `console.warn` when it doesn't. `json` is a JSON object with a `message` string and the optional strings `element`, `attribute`, `value`, and `location`. The first three name the element, the attribute, and the value that the warning is about. `location` is where the element is in the app's source, as `file:line:column`. The bundle sends each warning once per load. A host should show these warnings to the developer, and it may drop repeats.

In development builds, every element also has a `data-loc` attribute that holds its source location in the same form, so a host can name the location in its own warnings. A host must not treat `data-loc` as an attribute that changes how the element looks or behaves.

## 9. Element vocabulary

### 9.1 Where the vocabulary is defined

The element names, attribute names, and value types are defined in `src/elements.ts`. `docs/reference.md` is generated from that file, so this section does not list them. This section defines the contract that every host must meet, whichever element or attribute it renders.

### 9.2 Required and optional support

Every host must support these attribute groups, with the value types and units that Section 9.3 gives:

- **Layout.** Padding, frame sizes (`width`, `height`, and their minimum, ideal, and maximum forms), `framealignment`, and `fixedsize`.
- **Appearance.** Foreground `color`, `background`, `opacity`, `hidden`, `disabled`, `radius`, and `border`.
- **Text.** `font`, `size`, `weight`, `design`, and `italic`, on elements that show text.
- **Accessibility.** The attributes with the `a11y` prefix that `src/elements.ts` defines for labels, values, hints, and traits. A host must support each one it can express.
- **Gestures and lifecycle.** `ontap`, `onappear`, `ondisappear`, `ontask` with `taskid`, `onlongpress`, and `ondrag`, where the host can detect them.

A host may omit the following, but it must not crash on them, and it must report them as unsupported (Section 9.5): the iOS-only effects and styles in Section 9.7, symbol effects, and any attribute that depends on a platform concept the host does not have.

### 9.3 Value types and units

- **Lengths** are numbers in points. A Compose host treats one point as one density-independent pixel at font scale 1. A negative length is treated as zero.
- **Flexible size** is the string `"infinity"`. A host must treat it as "fill the available space" for the axis that the attribute names.
- **Opacity, visibility threshold, sensory intensity, gradient location, and symbol value** are unitless numbers. Opacity and locations are between 0 and 1.
- **Angles** are numbers in degrees.
- **Durations** for animation, delays, debounce, and long press are numbers in milliseconds. Hosts must use these units exactly.
- **Percentages** are not sent as a unit. A number is a fraction. For example, `0.5` means fifty percent.
- **Detent heights** are `"medium"`, `"large"`, `{ "fraction": number }` for a fraction of the screen height greater than 0 and at most 1, or `{ "points": number }` for a height in points. A host ignores any other value.

### 9.4 Colors and ShapeStyle

A color is a string in one of these forms:

- A named color from the cross-platform list in `src/elements.ts` (the `NamedColor` type).
- A hex color with 3, 4, 6, or 8 digits, after `#`, in either case.
- `rgb(r, g, b)`, `rgba(r, g, b, a)`, `hsl(h, s%, l%)`, or `hsla(h, s%, l%, a)`. Components may be separated by commas or spaces, and the alpha value is a fraction from 0 to 1.

System color names (the `SystemColor` type, such as `systemBlue`) are iOS names. A host that does not have them must map each name to the nearest equivalent in its own theme, and it must document the mapping. A host must not reject a name silently.

A ShapeStyle is one of:

- A color string.
- A hierarchical style: `tertiary`, `quaternary`, or `quinary`.
- A material: `ultraThinMaterial`, `thinMaterial`, `regularMaterial`, `thickMaterial`, `ultraThickMaterial`, or `bar`.
- A gradient object of one of these kinds: `{ linear, start, end }`, `{ radial, center, startRadius, endRadius }`, or `{ angular, center, startAngle, endAngle }`. Each gradient also carries its color stops, in the form that `src/elements.ts` defines. A stop is a color, or a color with a location.
- A named color with a `.gradient` suffix, which the iOS host also accepts.

Defaults that the TypeScript types do not show: a radial gradient's start radius is `0` and its end radius is `100`; an angular gradient runs from `0` to `360` degrees; a single stop sits at location `0`; a linear gradient with no start and end runs from top to bottom.

If a ShapeStyle is not recognized, the host must render the element without that style, and it must report the value as unsupported (Section 9.5). It must not substitute a default color without a report.

### 9.5 Reporting what cannot be rendered

A host must report each unsupported element name, attribute name, enum value, or ShapeStyle kind in its log, at the warning level, at most once per name. It must not stop rendering because of one. An unknown element that is not a native component renders as nothing. In development builds, the host may show a visible placeholder in its place.

The bundle warns in development about unknown elements and attributes. A host's log therefore matters most for values the bundle cannot check, such as enum values.

### 9.6 Enum values

Each enum value in `src/elements.ts` is part of the contract. A host must accept every value that the TypeScript type allows. For a value it cannot render, it must use the nearest equivalent and report it (Section 9.5). An unknown value must fall back to the attribute's documented default, not to an arbitrary branch.

These enum values are iOS-only in this version: sensory feedback names (`sensoryfeedback`), navigation title display modes, tab bar minimization, the glass attributes (`glasseffect`, `glassid`, `glassunion`, `glasseffectcontainer`, and glass button styles), search placement `navigationBarDrawer`, popover adaptation, list styles `grouped` and `insetGrouped`, picker styles `wheel` and `navigation`, the date picker `wheel` style, keyboard types `twitter`, `webSearch`, `namePhone`, and `asciiNumber`, text content types, submit labels `join`, `route`, `continue`, and `return`, PostScript font names (`fontname` and `fontfallbacks`), and the symbol attributes (Section 9.7).

The SwiftUI host builds for iOS, macOS, and visionOS, and on visionOS it uses these fallbacks. visionOS has no Liquid Glass, so the glass attributes have no effect there, the `glass` and `glassProminent` button styles look like `bordered` and `borderedProminent`, and a sheet's glass background uses the regular material. Toolbar spacers, navigation subtitles, and `scrolldismisseskeyboard` have no effect, a toolbar item placed on the `keyboard` uses the `automatic` placement, and an inspector is presented as a sheet. Sensory feedback needs visionOS 26 or later.

### 9.7 iOS-only concepts

Every host that does not have these concepts must document them as iOS-only, or give them a documented fallback:

- **SF Symbols.** The `sfsymbol` element, and every attribute that takes a symbol name (tab icons, labels, search tokens, content unavailable views, and menus). The symbol names are Apple's, so a Compose host must map them to its own icon set and report the names it cannot map.
- **Liquid Glass.** Glass material, glass effect containers, and glass button styles.
- **VoiceOver-only traits and gestures.** Traits such as `allowsDirectInteraction` and `causesPageTurn`, the escape and magic-tap gestures, and Voice Control labels.
- **Haptics.** Sensory feedback is modeled on the UIKit feedback generators.
- **Keyboard dismissal** modes and the keyboard safe-area region.
- **Dynamic type names** `accessibility1` through `accessibility5` are the iOS scale. A Compose host maps them to its own font scale.
- **Materials.** The system materials are Apple's blur styles, and a Compose host should approximate them.

Each of these must be a documented no-op or fallback, not a failure.

### 9.8 Special attributes

- `class` is resolved in the bundle and never sent (Section 3.4.5).
- `listens` is owned by the bundle (Section 3.6.1).
- `disabled` is sent to the host as an attribute. The bundle also reads it to evaluate `disabled:` class conditions.
- Event handler attributes (`on...`) are never sent. The bundle maps each one to its event type and sends the `listens` array.
- Two-way bound attributes are written back by the host through events. A toggle sends its `change` event, and the bundle writes the new `checked` value back as an attribute. Tab views, lists, searchable fields, and split views follow the same pattern with their own event names.
- `ref` is not an attribute. It is a bundle-side handle that uses invocations (Section 4).
- `format` on a text field selects a number field, and `multiple` on a picker selects the multiple-selection style. The host must honor both.
- `animation` accepts a curve name, an object, `true`, or `false`. `true` uses the default curve, and `false` turns the animation off. When the attribute is absent, `animated` and `transition` use the default curve, and images apply no animation.

## 10. Versioning

### 10.1 What `protocol` means

`protocol` is an integer that names the wire format of the render protocol (Section 3) and the `__native*` and `__svelte*` globals that carry it. It is sent in each `root` record. The `protocol` value in `src/renderer.ts` is `3`.

`protocol` does not describe the npm package version or the Swift package version. Those are separate, and a release may change one without changing the other.

### 10.2 When to bump it

Increase `protocol` when a change would make an older host misread or mishandle a message from a newer bundle, or the reverse. This includes:

- Changing the meaning, order, or count of operands for any opcode.
- Changing an opcode number, or adding a new opcode that an older host would reject.
- Changing how a value is encoded, for example how text IDs are signed, or how `null` is treated.
- Changing the signature or argument order of any `__native*` or `__svelte*` global.
- Changing the meaning of a required payload field.

Do not bump `protocol` for changes that an older host can safely ignore:

- New element names or attributes, provided that hosts ignore unknown attributes and elements (Section 9.5).
- New invocation methods, provided that hosts ignore unknown methods.
- New enum values, provided that hosts fall back as Section 9.6 requires.
- New fields in the environment snapshot, provided that hosts ignore fields they do not know.
- New native modules or methods that the bundle only calls when it detects them.

When a change is additive and an older host would otherwise fail, the change is a bump. When in doubt, bump.

### 10.3 Detection

The host checks `protocol` in the `root` record before it applies anything from that batch, as Section 3.4.1 describes. A host must refuse to render a mount whose protocol it does not implement, show the user an error that names both versions, and log the error. The iOS host detects this mismatch and shows that error.

Before it mounts a component, the bundle reads `__nativeProtocols`, an array of the protocol versions the host implements. The host must install it before it loads the bundle. If the array doesn't include the bundle's `protocol`, the bundle sends the `root` record so the host can show its error, logs a warning that names both versions, and doesn't mount the component. The bundle treats a host without `__nativeProtocols` as one that implements protocol 3 only. A future bundle that implements more than one protocol uses the array to pick one that the host implements.

When the bundle is evaluated, it sets the global `__svelteBundle` to `{ "version": string, "protocol": number }`, the npm release that built it and the protocol it uses. A host reads it after evaluation, so it can name both releases in its errors, including when no `root` record arrives. A bundle without `__svelteBundle` comes from swiftui-svelte 0.2.0 or earlier.

### 10.4 Compatibility

A host implements exactly one protocol version. A release of the bundle is compatible with a release of the host only when both use the same `protocol`. The release notes for each version must list the host releases that support it.

## 11. Planned changes

These are known gaps in protocol 3. They are not part of the normative behavior above, and a host must not depend on them.

- A standard way for a host to report unsupported values to the bundle, in addition to logs.
- Pause and resume for `onData` in fetch.
- Writing each storage key separately for `localStorage`, instead of saving the whole map at once.
- Reporting a rejected promise from an async handler of an event that carries no request, and reporting unhandled promise rejections in general. Today neither reaches the host.

## 12. Conformance

A host conforms to protocol 3 when it does all of these:

1. It checks the `root` protocol version before it applies any operation from that batch, and it refuses mismatches without applying any of the batch.
2. It keeps the name table for the life of the engine instance, and it resets it when the engine restarts.
3. It stores text nodes under their positive IDs, whatever sign the insert record uses.
4. It treats `null` attribute values as absence, the same as `unattr`.
5. It applies each batch as one transaction, and it rejects a malformed batch as a whole. It remounts after a malformed batch, and it stops if the remounted app sends another malformed batch before it applies a clean one.
6. It frees a subtree on `remove`, and it ignores removes of unknown IDs.
7. It keeps native state across `move`, including across parents.
8. It sends events only for types in `listens`, except the exceptions in Section 3.6.1.
9. It replies to every `measure` request, and it waits for `settled` before it finishes any operation that an event carrying a request started.
10. It implements every built-in module method with its documented argument order and result.
11. It sends the complete environment snapshot once, and it resends each field when its value changes.
12. It delivers `openurl` for every URL, including ones that arrive before the bundle loads.
13. It implements the `__native*` globals in Sections 6 to 8, and it fails the random and digest calls as Section 8.5 requires.
14. It reports unsupported values through its log, once per name, and it never stops rendering because of one.
15. It installs `__nativeProtocols` with the protocol versions it implements before it loads the bundle.
16. It ignores invocation methods that it doesn't implement, and it logs each unknown method once (Section 4).
17. It logs uncaught exceptions from the engine, including handler errors that the bundle rethrows, and it keeps running (Section 3.6.3).

### 12.1 Status of the iOS host

The iOS host in `Sources/SvelteSwiftUI` meets every item. The table lists the tests that check each one. Test names are Swift Testing functions in `Tests/SvelteSwiftUITests`, except the ones that start with `test`, which are XCUITests in `example/ios/SvelteHostUITests`.

| Item | Checked by                                                                                                                                                            |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `conformance/batches.json`, `NodeStoreTests.refusesAnIncompatibleBundle`, `RecoveryTests.showsAProtocolMismatch`                                                      |
| 2    | `conformance/batches.json`, `conformance/renderer.json`, `BundleTests.mountsAgainAfterAReload`                                                                        |
| 3    | `conformance/batches.json`                                                                                                                                            |
| 4    | `conformance/batches.json`                                                                                                                                            |
| 5    | `conformance/batches.json`, and the remount tests in `RecoveryTests`                                                                                                  |
| 6    | `conformance/batches.json`, `NodeStoreTests.forgetsEveryNodeOfALargeRemovedSubtree`                                                                                   |
| 7    | `conformance/batches.json`, `NodeStoreTests.movesANodeToAnotherParent`, `testReordersAndDeletesTodosInEditMode`                                                       |
| 8    | `ScrollingTests.readsWhichEventsAnElementListensFor`                                                                                                                  |
| 9    | `RuntimeTests.answersPendingMeasurementsWithNullWhenTheElementIsRemoved`, `RuntimeTests.waitsForAnAwaitedDispatchToSettle`, `testPullsToRefreshAndWaitsForTheHandler` |
| 10   | `NativeTests.registersTheBuiltInModules`, `NativeTests.callsModuleFunctionsWithTypedArgumentsAndResults`, `testRendersNativeComponentsAndCallsNativeModules`          |
| 11   | `EnvironmentTests.describesTheSwiftUIEnvironmentForJavaScript`, `WebAPITests.forwardsHostEnvironmentChangesToJavaScript`                                              |
| 12   | `RuntimeTests.holdsURLsThatArriveBeforeTheRuntimeStarts`, `OpenURLTests`                                                                                              |
| 13   | `WebAPITests.passesTheSharedWebSuiteInJavaScriptCore`, `WebAPITests.exposesTheNativeCryptoAndProtocolGlobalsWithTheirErrors`                                          |
| 14   | `DiagnosticsTests.reportsEachDiagnosticOnceWhereverItComesFrom`                                                                                                       |
| 15   | `WebAPITests.exposesTheNativeCryptoAndProtocolGlobalsWithTheirErrors`                                                                                                 |
| 16   | `RuntimeTests.remembersEachUnknownInvocationMethodOnceAndIgnoresIt`                                                                                                   |
| 17   | `RecoveryTests.reportsExceptions`                                                                                                                                     |

No test makes the platform's random source fail, so the failure path of item 13 is checked by reading the code, not by a test.

### 12.2 Conformance fixtures

The `conformance` directory holds fixtures that any host can replay without a JavaScript engine. Both files are JSON.

`batches.json` checks single batches against the rules in Section 3. It has a `protocol` field and a `cases` array. Each case has:

- `label`: what the case checks.
- `rule`: the sections of this document that the case checks.
- `batches`: an array of `[commit, result]` pairs, applied in order to a new host. `commit` is the batch as the string that `__nativeCommit` receives. `result` is `"applied"`, `"malformed"`, or `"incompatible"`.
- `tree`: the tree dump after the last batch.

`renderer.json` is an op log that the JavaScript test suite records from the renderer as it mounts and updates the components in `test/components`. It has a `steps` array. Each step has a `label`, the `commits` that the bundle sent for it, and the `tree` dump after the host applies them. A host passes when it reproduces every dump.

A tree dump starts at the root fragment of the mount, or of the mount with the highest mount ID when there are several. It has one line per node. Each node's children follow it in order, indented two spaces more than their parent:

- A fragment is `#fragment`.
- An element is `<name key=value …>`, with its attributes sorted by key. Each value is canonical JSON.
- A text node is `#text` followed by its string as a JSON string.
- With no mount, the dump is the empty string.

Canonical JSON writes integers without a decimal point, sorts object keys, and doesn't escape `/`.

The iOS host replays both files in `ConformanceTests`, and the JavaScript test suite rewrites `renderer.json` whenever it runs. A new host should replay both files in its own test suite.
