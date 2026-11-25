<script lang="ts">
  const {
    name,
    count = 0,
    onsave,
  }: {
    name: string;
    count?: number;
    onsave?: (value: unknown) => void;
  } = $props();
</script>

<txt>{name}: {count}</txt>
<btn onclick={() => onsave?.({ name, count, at: new Date(0) })}>Save</btn>
