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
