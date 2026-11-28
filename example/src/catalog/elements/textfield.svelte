<script lang="ts">
  let email = $state("");
  let bio = $state("");
  let saved = $state("");
  let price: number | null = $state(9.99);
</script>

<formview>
  <textfield
    placeholder="Email"
    keyboard="email"
    contenttype="email"
    autocapitalize="never"
    autocorrect={false}
    submitlabel="next"
    value={email}
    oninput={(value) => (email = value)}
  />
  <textfield
    placeholder="Styled placeholder"
    placeholdercolor="red"
    value=""
    oninput={() => {}}
  />
  <textfield
    placeholder="Bio"
    axis="vertical"
    lines={[2, 4]}
    debounce={1000}
    value={bio}
    oninput={(value) => (bio = value)}
  />
  <btn onclick={() => (saved = bio)}>Save bio</btn>
  <txt>Saved bio: {saved}</txt>
  <textfield
    format={{ currency: "USD" }}
    value={price}
    oninput={(value: number | null) => (price = value)}
  />
</formview>
