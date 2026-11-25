<script lang="ts">
  import {
    DatePicker,
    Picker,
    Slider,
    Stepper,
    Toggle,
  } from "swiftui-svelte/components";
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
</script>

<navstack>
  <screen title="Settings">
    <formview tint={accent}>
      <sectionview header="Accent color">
        <Picker
          label="Accent color"
          variant="segmented"
          bind:value={
            () => accent,
            (value) =>
              (accent = accents.find((name) => name === value) ?? "blue")
          }
        >
          <choice value="blue">Blue</choice>
          <choice value="orange">Orange</choice>
          <choice value="green">Green</choice>
          <choice value="pink">Pink</choice>
        </Picker>
      </sectionview>

      <sectionview
        header="Daily goal"
        footer="Finished to-dos count toward today's goal."
      >
        <Stepper bind:value={goal} min={1} max={20}>
          <txt>{goal} {goal === 1 ? "to-do" : "to-dos"} a day</txt>
        </Stepper>
        <progressview value={done} total={goal}>
          <txt>{Math.min(done, goal)} of {goal} done</txt>
        </progressview>
      </sectionview>

      <sectionview header="Reminders">
        <Toggle bind:checked={reminds}>
          <txt>Remind me</txt>
        </Toggle>
        {#if reminds}
          <DatePicker components="time" bind:value={reminderTime}>
            <txt>Time</txt>
          </DatePicker>
          <Picker label="Repeat" variant="menu" bind:value={repeat}>
            <choice value="daily">Every day</choice>
            <choice value="weekdays">Weekdays</choice>
            <choice value="weekends">Weekends</choice>
          </Picker>
        {/if}
      </sectionview>

      <sectionview header="Sound">
        <hstack spacing={12}>
          <sfsymbol name="speaker.fill" color="secondary" />
          <Slider bind:value={volume}>
            <txt>Volume</txt>
          </Slider>
          <sfsymbol name="speaker.wave.3.fill" color="secondary" />
        </hstack>
        <Picker label="Tone" variant="navigation" bind:value={tone}>
          <choice value="chime" symbol="bell">Chime</choice>
          <choice value="glass" symbol="wineglass">Glass</choice>
          <choice value="pulse" symbol="waveform">Pulse</choice>
        </Picker>
      </sectionview>
    </formview>
  </screen>
</navstack>
