<script lang="ts">
  let open = $state(false);
  let source = $state("nothing yet");
</script>

<vstack spacing={12}>
  <btn variant="bordered" onclick={() => (open = true)}>
    Change the photo
    {#if open}
      <confirmationdialog
        title="Change the photo"
        titlevisibility="visible"
        ondismiss={() => (open = false)}
      >
        <btn onclick={() => (source = "the camera")}>Take a photo</btn>
        <btn onclick={() => (source = "the library")}
          >Choose from the library</btn
        >
        <btn role="cancel">Cancel</btn>
      </confirmationdialog>
    {/if}
  </btn>
  <txt color="secondary">Picked {source}</txt>
</vstack>
