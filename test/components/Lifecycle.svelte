<script lang="ts">
  import { log, signals } from "./lifecycle.ts";

  let page = $state(1);
</script>

<vstack
  testid="page"
  taskid={page}
  onappear={() => log.push("appear")}
  ondisappear={() => log.push("disappear")}
  ontask={(signal) =>
    new Promise<void>((resolve, reject) => {
      log.push(`load ${page}`);
      signals.push(signal);
      signal.addEventListener("abort", () => {
        log.push(`cancel ${page}`);
        reject(signal.reason);
      });
    })}
/>
<vstack
  testid="quick"
  ontask={() => {
    log.push("quick");
  }}
/>
<btn testid="next" onclick={() => page++}>Next</btn>
