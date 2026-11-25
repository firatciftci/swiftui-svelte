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
