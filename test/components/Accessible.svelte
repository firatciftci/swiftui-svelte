<script lang="ts">
  let rating = $state(3);
  let last = $state("none");
</script>

<hstack
  testid="rating"
  a11ychildren="combine"
  a11ylabel="Rating"
  a11yvalue={rating}
  a11yhint="Swipe up or down to change the rating"
  a11ytraits={["button", "selected"]}
  a11yactions={["Reset", "Maximum"]}
  ona11yaction={(name) => {
    last = name;
    rating = name === "Reset" ? 0 : 5;
  }}
  ona11yadjust={(direction) => (rating += direction === "increment" ? 1 : -1)}
>
  <sfsymbol name="star.fill" />
  <txt>{rating}</txt>
</hstack>
<txt testid="title" a11yheading={1} a11ysortpriority={2}>Ratings</txt>
<txt testid="decoration" a11yhidden>★★★</txt>
<txt testid="last">{last}</txt>
