<script lang="ts">
  let status = $state("Loading");
</script>

<vstack spacing={8}>
  <asyncimage
    src="https://github.com/sveltejs.png"
    fit="fill"
    width={120}
    height={120}
    radius={24}
    onload={() => (status = "Loaded")}
    onerror={(message) => (status = message)}
  />
  <txt font="caption" color="secondary">{status}</txt>
</vstack>
