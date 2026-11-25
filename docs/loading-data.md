# Loading data

`fetch` works as it does in a browser, backed by `URLSession`, so most of what you know about loading data on the web carries over. What's different is when to start a request and how to show its progress, and for that swiftui-svelte gives you SwiftUI's own tools: `ontask`, pull to refresh, and rows that tell you when they appear.

## A list from an API

This screen loads Svelte's repositories from GitHub 20 at a time. It shows a spinner while a page loads, an error with a button to try again, the next page when the user scrolls to the end, and fresh data when the user pulls down:

```svelte
<script lang="ts">
  type Repo = { id: number; full_name: string; stargazers_count: number };

  let repos: Array<Repo> = $state([]);
  let failure: string | null = $state(null);
  let loading = $state(false);
  let page = 1;
  let finished = false;

  async function load(signal?: AbortSignal) {
    if (loading || finished) return;
    loading = true;
    failure = null;
    try {
      const response = await fetch(
        `https://api.github.com/orgs/sveltejs/repos?per_page=20&page=${page}`,
        { signal },
      );
      if (!response.ok) throw new Error(`GitHub answered ${response.status}.`);
      const next = (await response.json()) as Array<Repo>;
      repos.push(...next);
      page += 1;
      finished = next.length < 20;
    } catch (error) {
      if (!signal?.aborted)
        failure = error instanceof Error ? error.message : String(error);
    } finally {
      loading = false;
    }
  }

  async function refresh() {
    repos = [];
    page = 1;
    finished = false;
    await load();
  }
</script>

<navstack>
  <screen title="Repositories">
    <list ontask={(signal) => load(signal)} onrefresh={refresh}>
      {#each repos as repo, index (repo.id)}
        <labeledcontent
          title={repo.full_name}
          value={repo.stargazers_count}
          onappear={index === repos.length - 1 ? () => load() : undefined}
        />
      {/each}
      {#if loading}
        <progressview />
      {:else if failure != null}
        <contentunavailableview
          title="Couldn't load the repositories"
          symbol="wifi.exclamationmark"
          description={failure}
        >
          <btn variant="bordered" onclick={() => load()}>Try again</btn>
        </contentunavailableview>
      {/if}
    </list>
  </screen>
</navstack>
```

## Starting a request

- **`ontask`** runs when the element appears, like SwiftUI's `.task`. It receives an `AbortSignal` that aborts when the element disappears, so pass the signal to `fetch`, and a request that the user no longer needs gets canceled. When the user pops a screen off the stack or leaves a tab, its requests are canceled this way.
- **`taskid`** runs `ontask` again whenever its value changes, aborting the previous run first. Set it to a search query or a selected item's ID, and the element loads the new data while the old request is canceled. Combine it with `debounce` on the search field so that a request doesn't start on every keystroke.
- **`onappear`** on the last row loads the next page when the user scrolls to the end, as in the list above. Rows in a `list` or a lazy stack appear as they scroll into view, so this doesn't load pages the user never sees.
- **`onrefresh`** on a `list` or a `scrollview` lets the user pull down to refresh. When the handler returns a promise, the spinner stays until the promise settles.
- **Event handlers** start any other request: a button's `onclick` or a field's `onsubmit` can be an `async` function.

Keep the state that a request fills in `$state`, as `repos`, `loading`, and `failure` are above, and Svelte updates the screen as each one changes. Values that only the loading code reads, like `page` above, can be plain variables.

## Errors and timeouts

`fetch` rejects when the network fails and resolves when the server answers, even with an error status, so check `response.ok`. When a request is aborted, it rejects with an `AbortError`, which usually isn't worth showing, so the list above checks `signal.aborted` before it shows the error. To give up on a slow server, pass `AbortSignal.timeout(10_000)` as the signal.

`navigator.onLine` says whether the device has a network connection, and the global object fires `online` and `offline` events when that changes, so you can try again when the connection comes back.

An error thrown while rendering, such as reading a property of data that hasn't arrived, is different from a failed request. Wrap the part of the screen that renders the data in `<svelte:boundary>` to show a fallback in its place. [Debugging](debugging.md) has more.

## Showing the last data right away

Saving the last response lets the screen show it at once on the next launch, while a new request runs. `localStorage` is saved in `UserDefaults`, so it survives relaunches. It suits small values such as settings, a user profile, or the first page of a list:

```ts
let repos: Array<Repo> = $state(
  JSON.parse(localStorage.getItem("repos") ?? "[]") as Array<Repo>,
);

$effect(() => {
  localStorage.setItem("repos", JSON.stringify(repos));
});
```

For larger data, write a file with the `files` module from `swiftui-svelte/native`, which keeps files in the app's Application Support folder. [Native modules](native-modules.md) lists its functions.

## Live data

`WebSocket` runs on `URLSessionWebSocketTask`, with text and binary messages. Open it in an `$effect` and close it in the function the effect returns, so it closes when the component goes away:

```ts
let price = $state<number | null>(null);

$effect(() => {
  const socket = new WebSocket("wss://example.com/prices");
  socket.addEventListener("message", (event) => {
    price = Number(event.data);
  });
  return () => socket.close();
});
```

`fetch` also streams the response body as data arrives, so `response.body` works for server-sent events. [Web APIs](web-apis.md) lists the APIs and the few ways they differ from a browser.
