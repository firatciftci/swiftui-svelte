<script lang="ts">
  const { title, closeToast }: { title: string; closeToast: () => void } =
    $props();
</script>

<hstack
  spacing={12}
  padding={{ horizontal: 16, vertical: 12 }}
  radius={20}
  glasseffect={{ tint: "purple" }}
  background="regularMaterial"
>
  <sfsymbol name="sparkles" font="title3" color="purple"></sfsymbol>
  <txt font="headline">{title}</txt>
  <spacer minlength={0}></spacer>
  <btn variant="plain" onclick={closeToast}>
    <sfsymbol name="xmark" font="footnote" weight="semibold"></sfsymbol>
  </btn>
</hstack>
