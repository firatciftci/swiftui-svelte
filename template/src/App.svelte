<script lang="ts">
  let count = $state(0);
</script>

<navstack>
  <screen title="__APP_NAME__">
    <list>
      <sectionview>
        <txt font="title2" weight="semibold">Welcome to __APP_NAME__</txt>
        <txt color="secondary"
          >Edit src/App.svelte and save, and the app reloads with your change.</txt
        >
      </sectionview>
      <sectionview>
        <btn onclick={() => count++}>Tap me</btn>
        <txt>Tapped {count} times</txt>
      </sectionview>
    </list>
  </screen>
</navstack>
