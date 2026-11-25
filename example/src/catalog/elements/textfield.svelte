<script lang="ts">
  let email = $state("");
  let bio = $state("");
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
    placeholder="Bio"
    axis="vertical"
    lines={[2, 4]}
    debounce={300}
    value={bio}
    oninput={(value) => (bio = value)}
  />
  <textfield
    format={{ currency: "USD" }}
    value={price}
    oninput={(value: number | null) => (price = value)}
  />
</formview>
