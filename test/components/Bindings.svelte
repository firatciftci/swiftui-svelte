<script lang="ts">
  import {
    Alert,
    ColorPicker,
    DatePicker,
    DisclosureGroup,
    MultiDatePicker,
    MultiPicker,
    NumberField,
    Picker,
    SecureField,
    Sheet,
    Slider,
    Stepper,
    TabView,
    TextEditor,
    TextField,
    Toggle,
  } from "swiftui-svelte/components";

  let name = $state("");
  let short = $state("");
  let isOn = $state(false);
  let flavor = $state("vanilla");
  let volume = $state(0.5);
  let count = $state(1);
  let date = $state(new Date(0));
  let tab = $state("home");
  let isSheetPresented = $state(false);
  let isAlertPresented = $state(false);
  let submitted = $state(0);
  let changes = $state(0);
  let isExpanded = $state(false);
  let password = $state("");
  let notes = $state("");
  let price = $state<number | null>(4.5);
  let toppings = $state<Array<string | number>>(["cheese"]);
  let days = $state<Array<string>>([]);
  let color = $state("#FF0000");
</script>

<TextField testid="name" bind:value={name} onsubmit={() => submitted++} />
<TextField
  testid="short"
  bind:value={() => short, (next) => (short = next.slice(0, 3))}
/>
<SecureField testid="password" bind:value={password} contenttype="password" />
<TextEditor testid="notes" bind:value={notes} />
<NumberField testid="price" bind:value={price} format={{ currency: "USD" }} />
<MultiPicker testid="toppings" label="Toppings" bind:value={toppings}>
  <choice value="cheese">Cheese</choice>
  <choice value="olives">Olives</choice>
</MultiPicker>
<MultiDatePicker testid="days" bind:value={days}>Days</MultiDatePicker>
<ColorPicker testid="color" bind:value={color}>Color</ColorPicker>
<Toggle testid="on" bind:checked={isOn} onchange={() => changes++}>Wi-Fi</Toggle
>
<Picker testid="flavor" bind:value={flavor}>
  <choice value="vanilla">Vanilla</choice>
  <choice value="mint">Mint</choice>
</Picker>
<Slider testid="volume" bind:value={volume} />
<Stepper testid="count" bind:value={count} min={0} max={3}>Count</Stepper>
<DatePicker testid="date" bind:value={date} />
<TabView testid="tabs" bind:selection={tab}>
  <tab title="Home" value="home"><txt>Home</txt></tab>
  <tab title="Settings" value="settings"><txt>Settings</txt></tab>
</TabView>
<btn
  testid="open"
  onclick={() => {
    isSheetPresented = true;
    isAlertPresented = true;
  }}>Open</btn
>
<DisclosureGroup testid="more" title="More" bind:expanded={isExpanded}>
  <txt>Details</txt>
</DisclosureGroup>
<Sheet bind:presented={isSheetPresented}><txt>In a sheet</txt></Sheet>
<Alert bind:presented={isAlertPresented} title="Saved"><btn>OK</btn></Alert>
<txt testid="state"
  >{JSON.stringify({
    name,
    short,
    isOn,
    flavor,
    volume,
    count,
    date: date.getTime(),
    tab,
    isSheetPresented,
    isAlertPresented,
    submitted,
    changes,
    isExpanded,
    password,
    notes,
    price,
    toppings,
    days,
    color,
  })}</txt
>
