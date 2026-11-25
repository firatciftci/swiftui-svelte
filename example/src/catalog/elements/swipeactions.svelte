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
