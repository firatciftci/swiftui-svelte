# Forms

A form in swiftui-svelte is a `formview`, the grouped look of the Settings app, with its rows grouped into `sectionview` elements. The controls are SwiftUI's own, so they handle Dynamic Type, VoiceOver, AutoFill, and the keyboard for you.

## A sign-up form

```svelte
<script lang="ts">
  import { ref } from "swiftui-svelte";
  import { Picker, TextField, Toggle } from "swiftui-svelte/components";

  let name = $state("");
  let email = $state("");
  let plan = $state<string | number>("free");
  let newsletter = $state(true);
  let submitted = $state(false);
  const emailField = ref();

  const valid = $derived(name.trim() !== "" && email.includes("@"));
</script>

<navstack>
  <screen title="Sign up">
    <formview>
      <sectionview header="About you">
        <TextField
          placeholder="Name"
          contenttype="name"
          submitlabel="next"
          bind:value={name}
          onsubmit={() => emailField.focus()}
        />
        <TextField
          {@attach emailField}
          placeholder="Email"
          keyboard="email"
          contenttype="email"
          autocapitalize="never"
          autocorrect={false}
          submitlabel="done"
          bind:value={email}
        />
      </sectionview>
      <sectionview header="Plan" footer="You can change your plan at any time.">
        <Picker label="Plan" bind:value={plan}>
          <choice value="free">Free</choice>
          <choice value="pro">Pro</choice>
        </Picker>
        <Toggle bind:checked={newsletter}>Send me the newsletter</Toggle>
      </sectionview>
      <sectionview>
        <btn disabled={!valid} onclick={() => (submitted = true)}
          >Create account</btn
        >
      </sectionview>
    </formview>
    {#if submitted}
      <alert title="Welcome, {name}!" ondismiss={() => (submitted = false)}>
        <btn role="cancel">OK</btn>
      </alert>
    {/if}
  </screen>
</navstack>
```

## Binding values

Svelte doesn't allow `bind:` on elements in custom renderer components, so each element is controlled: it shows `value` or `checked`, and it reports changes through `oninput` or `onchange`. The components in `swiftui-svelte/components` wrap the controls with bindable props, so `<TextField bind:value={name} />` works as it would on the web. Use elements when you want to change a value before it reaches your state, and components when you just want the value. [Elements](elements.md#bindable-components) lists the components.

## Text fields and keyboards

- `keyboard` picks the keyboard, such as `email`, `number`, `decimal`, `phone`, or `url`.
- `contenttype` tells iOS what the field holds, such as `email`, `username`, `password`, `newPassword`, or `oneTimeCode`, so it can offer AutoFill and saved passwords.
- `submitlabel` sets the label on the Return key, such as `next`, `done`, `go`, or `send`, and `onsubmit` runs when the user presses it.
- `autocapitalize` and `autocorrect` turn off capitalization and autocorrection, which you'll want for email addresses and user names.
- `debounce` waits until the user stops typing before `oninput` runs, which helps when each change starts a search.
- `axis="vertical"` lets a field grow as the user types more lines, and `texteditor` edits longer text.
- A `securefield` hides what the user types.

## Numbers and dates

A `textfield` with a `format` edits a number: `format="integer"`, `format="percent"`, or `format={{ currency: "EUR" }}`. Its value is a number, or `null` when the field is empty, and it changes when the user presses Return or leaves the field. The `NumberField` component binds it. A `stepper` and a `slider` edit numbers with buttons and a track, and a `datepicker` picks a date, a time, or both.

## Moving focus

`ref()` gives you an element's methods, so `field.focus()` moves the cursor to a field and `field.blur()` hides the keyboard. Calling `focus()` in the previous field's `onsubmit`, as in the form above, lets the user move from field to field with the Return key. The `TextField` component also has a bindable `focused` prop for when you'd rather keep focus in your state.

To add a Done button above the keyboard, put a `toolbar` with `placement="keyboard"` in the screen. To let the user hide the keyboard by scrolling, set `scrolldismisseskeyboard="interactively"` on the `formview`.

## Validation

Keep validation in `$derived` state, as `valid` is in the form above, and pass it to `disabled` on the submit button. Show messages next to the field they're about, with a `txt` in the same section or in the section's `footer`. Because elements are controlled, you can also reject input as the user types: `oninput={(value) => (code = value.replace(/\D/g, "").slice(0, 6))}` keeps a field to six digits, and the field shows the cleaned-up text.

## Saving the form

To keep a draft when the user leaves the app, store it with `restorable` from `swiftui-svelte/app`, which saves to `localStorage` whenever the value changes. To send the form, call `fetch` from the submit button's `onclick`. [Loading data](loading-data.md) shows how to show progress and errors while the request runs.
