<script lang="ts">
  import { state } from "./state.svelte.ts";
</script>

<vstack
  data-number={state.values.number}
  data-boolean={state.values.boolean}
  data-string={state.values.string}
  data-array={state.values.array}
  data-object={state.values.object}
  data-date={state.values.date}
/>
