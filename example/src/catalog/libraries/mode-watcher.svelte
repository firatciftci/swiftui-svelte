<script lang="ts">
  import {
    mode,
    ModeWatcher,
    setMode,
    systemPrefersMode,
    userPrefersMode,
  } from "swiftui-svelte/mode-watcher";

  const options = [
    { value: "system", label: "System" },
    { value: "light", label: "Light" },
    { value: "dark", label: "Dark" },
  ] as const;
</script>

<ModeWatcher />

<vstack spacing={12} padding>
  {#each options as option (option.value)}
    <btn
      variant={userPrefersMode.current === option.value
        ? "prominent"
        : "bordered"}
      onclick={() => setMode(option.value)}
    >
      {option.label}
    </btn>
  {/each}
  <txt font="footnote" color="secondary">
    The app is showing {mode.current ?? "light"} mode.
  </txt>
  <txt font="footnote" color="secondary">
    The device is set to {systemPrefersMode.current ?? "light"} mode.
  </txt>
</vstack>
