<script lang="ts">
  let name = $state("");
  let notifications = $state(true);
</script>

<formview>
  <sectionview header="Profile">
    <textfield
      placeholder="Name"
      value={name}
      oninput={(value) => (name = value)}
    />
  </sectionview>
  <sectionview header="Preferences" footer="You can change this later.">
    <toggle checked={notifications} onchange={(next) => (notifications = next)}>
      Notifications
    </toggle>
  </sectionview>
</formview>
