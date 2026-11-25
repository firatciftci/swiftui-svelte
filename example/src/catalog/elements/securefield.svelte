<script lang="ts">
  let password = $state("");
</script>

<formview>
  <securefield
    placeholder="Password"
    contenttype="newPassword"
    value={password}
    oninput={(value) => (password = value)}
  />
  <txt font="caption" color={password.length >= 8 ? "green" : "secondary"}>
    At least 8 characters
  </txt>
</formview>
