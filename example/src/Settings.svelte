<script lang="ts">
  import { ref } from "swiftui-svelte";
  import {
    DatePicker,
    Picker,
    Slider,
    Stepper,
    Toggle,
  } from "swiftui-svelte/components";
  import { env } from "swiftui-svelte/env";
  import { language } from "./language.svelte";
  import { m } from "./paraglide/messages.js";
  import { isLocale } from "./paraglide/runtime.js";
  import { todos } from "./todos.svelte";

  const accents = ["blue", "orange", "green", "pink"] as const;

  function atNine() {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate(), 9);
  }

  let accent = $state<(typeof accents)[number]>("blue");
  let goal = $state(3);
  let reminds = $state(true);
  let reminderTime = $state(atNine());
  let repeat = $state<string | number>("daily");
  let volume = $state(0.6);
  let tone = $state<string | number>("chime");

  const done = $derived(todos.filter((todo) => todo.done).length);

  const form = ref();
  let formSize = $state("");

  $effect(() => {
    void env.horizontalSizeClass;
    void form.measure().then((rect) => {
      if (rect != null) {
        formSize = `${Math.round(rect.width)} × ${Math.round(rect.height)} pt`;
      }
    });
  });
</script>

<navstack>
  <screen title={m.settings_title()}>
    <formview tint={accent} {@attach form}>
      <sectionview header={m.language_header()} footer={m.language_footer()}>
        <Picker
          label={m.language_label()}
          variant="menu"
          bind:value={
            () => language.choice,
            (value) =>
              (language.choice =
                typeof value === "string" && isLocale(value) ? value : "system")
          }
        >
          <choice value="system">{m.language_system()}</choice>
          <choice value="en">English</choice>
          <choice value="ar">العربية</choice>
        </Picker>
      </sectionview>

      <sectionview header={m.accent_header()}>
        <Picker
          label={m.accent_header()}
          variant="segmented"
          bind:value={
            () => accent,
            (value) =>
              (accent = accents.find((name) => name === value) ?? "blue")
          }
        >
          <choice value="blue">{m.accent_blue()}</choice>
          <choice value="orange">{m.accent_orange()}</choice>
          <choice value="green">{m.accent_green()}</choice>
          <choice value="pink">{m.accent_pink()}</choice>
        </Picker>
      </sectionview>

      <sectionview header={m.goal_header()} footer={m.goal_footer()}>
        <Stepper bind:value={goal} min={1} max={20}>
          <txt>{m.goal_count({ count: goal })}</txt>
        </Stepper>
        <progressview value={done} total={goal}>
          <txt>{m.goal_progress({ done: Math.min(done, goal), goal })}</txt>
        </progressview>
      </sectionview>

      <sectionview header={m.reminders_header()}>
        <Toggle bind:checked={reminds}>
          <txt>{m.remind_me()}</txt>
        </Toggle>
        {#if reminds}
          <DatePicker components="time" bind:value={reminderTime}>
            <txt>{m.time()}</txt>
          </DatePicker>
          <Picker label={m.repeat()} variant="menu" bind:value={repeat}>
            <choice value="daily">{m.repeat_daily()}</choice>
            <choice value="weekdays">{m.repeat_weekdays()}</choice>
            <choice value="weekends">{m.repeat_weekends()}</choice>
          </Picker>
        {/if}
      </sectionview>

      <sectionview header={m.sound_header()}>
        <hstack spacing={12}>
          <sfsymbol name="speaker.fill" color="secondary" />
          <Slider bind:value={volume}>
            <txt>{m.volume()}</txt>
          </Slider>
          <sfsymbol name="speaker.wave.3.fill" color="secondary" />
        </hstack>
        <Picker label={m.tone()} variant="navigation" bind:value={tone}>
          <choice value="chime" symbol="bell">{m.tone_chime()}</choice>
          <choice value="glass" symbol="wineglass">{m.tone_glass()}</choice>
          <choice value="pulse" symbol="waveform">{m.tone_pulse()}</choice>
        </Picker>
      </sectionview>

      <sectionview footer={m.device_footer()}>
        <header>
          <hstack spacing={6}>
            <sfsymbol name="iphone" />
            <txt>{m.device_header()}</txt>
          </hstack>
        </header>
        {@render row(m.appearance(), env.colorScheme)}
        {@render row(m.text_size(), env.dynamicTypeSize)}
        {@render row(m.locale(), env.locale)}
        {@render row(m.layout_direction(), env.layoutDirection)}
        {@render row(m.width(), env.horizontalSizeClass ?? "")}
        {@render row(
          m.safe_area(),
          m.safe_area_value({
            top: Math.round(env.safeAreaInsets.top),
            bottom: Math.round(env.safeAreaInsets.bottom),
          }),
        )}
        {@render row(m.form_size(), formSize)}
      </sectionview>
    </formview>
  </screen>
</navstack>

{#snippet row(label: string, value: string)}
  <hstack>
    <txt>{label}</txt>
    <spacer />
    <txt color="secondary">{value}</txt>
  </hstack>
{/snippet}
