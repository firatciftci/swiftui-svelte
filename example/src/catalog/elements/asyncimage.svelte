<script lang="ts">
  let status = $state("Loading");
  let errors = $state(0);
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
  <asyncimage src="" width={60} height={60} onerror={() => (errors += 1)}>
    <failure>
      <sfsymbol
        testid="image-failure"
        name="photo.badge.exclamationmark"
        label="No image"
      />
    </failure>
  </asyncimage>
  <txt testid="image-errors" font="caption" color="secondary"
    >Errors: {errors}</txt
  >
</vstack>
