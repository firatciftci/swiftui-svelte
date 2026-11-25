<script lang="ts">
  let rating = $state(3);
  let favorite = $state(false);
  let playing = $state(false);
  let shared = $state(false);
</script>

<vstack
  alignment="leading"
  spacing={16}
  padding
  ona11ymagictap={() => (playing = !playing)}
  ona11yescape={() => (favorite = false)}
>
  <txt font="title2" weight="bold" a11yheading={1}>Accessibility</txt>
  <hstack
    a11ychildren="ignore"
    a11ylabel="Rating"
    a11yvalue="{rating} of 5 stars"
    ona11yadjust={(direction) =>
      (rating = Math.min(
        5,
        Math.max(1, rating + (direction === "increment" ? 1 : -1)),
      ))}
  >
    {#each [1, 2, 3, 4, 5] as star (star)}
      <sfsymbol name={star <= rating ? "star.fill" : "star"} color="yellow" />
    {/each}
  </hstack>
  <hstack
    testid="favorite"
    a11ychildren="combine"
    a11yhint="Adds the article to your favorites"
    a11yinputlabels={["Favorite", "Heart"]}
    a11ytraits={favorite ? ["button", "selected"] : "button"}
    a11yremovetraits="image"
    a11yactions={["Share"]}
    ona11yaction={() => (shared = true)}
    ona11yactivate={() => (favorite = !favorite)}
    ontap={() => (favorite = !favorite)}
  >
    <sfsymbol name={favorite ? "heart.fill" : "heart"} color="pink" />
    <txt>Favorite</txt>
  </hstack>
  <txt a11ysortpriority={1}>VoiceOver reads this line first.</txt>
  <sfsymbol name="sparkles" a11yhidden />
  <txt color="secondary">
    {playing ? "Playing" : "Paused"}{shared ? ", shared" : ""}
  </txt>
</vstack>
