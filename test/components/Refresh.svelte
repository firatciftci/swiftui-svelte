<script lang="ts">
  import { pending, refreshSignals } from "./refresh.ts";

  let refreshes = $state(0);
  let shows = $state(true);
</script>

{#if shows}
  <list
    testid="feed"
    onrefresh={() =>
      new Promise<void>((resolve) => {
        pending.push(() => {
          refreshes++;
          resolve();
        });
      })}
  >
    <txt>Refreshes {refreshes}</txt>
  </list>
{/if}
<scrollview
  testid="quick"
  onrefresh={() => {
    refreshes++;
  }}
/>
<scrollview
  testid="failing"
  onrefresh={async () => {
    throw new Error("offline");
  }}
/>
<scrollview
  testid="throwing"
  onrefresh={() => {
    throw new Error("unreachable");
  }}
/>
<scrollview
  testid="abortable"
  onrefresh={(signal) =>
    new Promise<void>((_, reject) => {
      refreshSignals.push(signal);
      signal.addEventListener("abort", () => reject(signal.reason));
    })}
/>
<scrollview testid="plain" />
<btn testid="hide" onclick={() => (shows = false)}>Hide</btn>
