<script lang="ts">
  import SuperDebug, { defaults, superForm } from "sveltekit-superforms";
  import { zod } from "sveltekit-superforms/adapters/zod4";
  import { z } from "zod";
  import { TextField } from "swiftui-svelte/components";

  const schema = z.object({
    name: z.string().min(2, "Enter at least 2 characters."),
    email: z.email("Enter a valid email address."),
  });

  const { form, errors, validateForm } = superForm(defaults(zod(schema)), {
    SPA: true,
    validators: zod(schema),
  });

  let created = $state("");

  async function createAccount() {
    const result = await validateForm({ update: true });
    created = result.valid ? result.data.name : "";
  }
</script>

<formview>
  <sectionview>
    <TextField
      placeholder="Name"
      bind:value={$form.name}
      testid="superforms-name"
    />
    {#if $errors.name}
      <txt color="red" font="footnote">{$errors.name[0]}</txt>
    {/if}
    <TextField
      placeholder="Email"
      bind:value={$form.email}
      testid="superforms-email"
    />
    {#if $errors.email}
      <txt color="red" font="footnote">{$errors.email[0]}</txt>
    {/if}
  </sectionview>
  <sectionview>
    <btn onclick={createAccount}>Create account</btn>
    {#if created !== ""}
      <txt>Account created for {created}.</txt>
    {/if}
  </sectionview>
  <sectionview>
    <SuperDebug data={$form} />
  </sectionview>
</formview>
