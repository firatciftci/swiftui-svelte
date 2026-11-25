<script lang="ts">
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
        <picker
          label="Accent color"
          variant="segmented"
          value={accent}
          onchange={(value) =>
            (accent = accents.find((name) => name === value) ?? "blue")}
        >
          <choice value="blue">Blue</choice>
          <choice value="orange">Orange</choice>
          <choice value="green">Green</choice>
          <choice value="pink">Pink</choice>
        </picker>
      </sectionview>

      <sectionview
        header="Daily goal"
        footer="Finished to-dos count toward today's goal."
      >
        <stepper
          value={goal}
          min={1}
          max={20}
          onchange={(value) => (goal = value)}
        >
          <txt>{goal} {goal === 1 ? "to-do" : "to-dos"} a day</txt>
        </stepper>
        <progressview value={done} total={goal}>
          <txt>{Math.min(done, goal)} of {goal} done</txt>
        </progressview>
      </sectionview>

      <sectionview header="Reminders">
        <toggle checked={reminds} onchange={(checked) => (reminds = checked)}>
          <txt>Remind me</txt>
        </toggle>
        {#if reminds}
          <datepicker
            components="time"
            value={reminderTime}
            onchange={(value) => (reminderTime = value)}
          >
            <txt>Time</txt>
          </datepicker>
          <picker
            label="Repeat"
            variant="menu"
            value={repeat}
            onchange={(value) => (repeat = value)}
          >
            <choice value="daily">Every day</choice>
            <choice value="weekdays">Weekdays</choice>
            <choice value="weekends">Weekends</choice>
          </picker>
        {/if}
      </sectionview>

      <sectionview header="Sound">
        <hstack spacing={12}>
          <sfsymbol name="speaker.fill" color="secondary" />
          <slider value={volume} oninput={(value) => (volume = value)}>
            <txt>Volume</txt>
          </slider>
          <sfsymbol name="speaker.wave.3.fill" color="secondary" />
        </hstack>
        <picker
          label="Tone"
          variant="navigation"
          value={tone}
          onchange={(value) => (tone = value)}
        >
          <choice value="chime" symbol="bell">Chime</choice>
          <choice value="glass" symbol="wineglass">Glass</choice>
          <choice value="pulse" symbol="waveform">Pulse</choice>
        </picker>
      </sectionview>
    </formview>
  </screen>
</navstack>
