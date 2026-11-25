<script lang="ts">
  let open = $state(false);
</script>

<btn variant="bordered" onclick={() => (open = true)}>
  What's new?
  {#if open}
    <popover
      adaptation="popover"
      arrowedge="top"
      ondismiss={() => (open = false)}
    >
      <txt padding width={240}
        >Popovers point at the button that opens them.</txt
      >
    </popover>
  {/if}
</btn>
