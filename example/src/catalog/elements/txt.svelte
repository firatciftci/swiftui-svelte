<vstack alignment="leading" spacing={12} padding>
  <txt font="title" weight="bold">Rich text</txt>
  <txt color="secondary">
    Spans can be <txt weight="bold" color="primary">bold</txt>,
    <txt italic>italic</txt>, or
    <txt href="https://svelte.dev" underline>links</txt>.
  </txt>
  <txt markdown="Markdown works **too**, with `code` and _emphasis_."></txt>
  <txt lines={1} truncation="middle">
    A long line of text that gets cut off in the middle when it doesn't fit
  </txt>
  <txt selectable font="footnote" tracking={2}>SELECT AND COPY ME</txt>
  <txt font="body"
    >Footnote<txt baselineoffset={6} font="caption">1</txt> and
    <txt underline underlinestyle="dotted" underlinecolor="red">dotted</txt>
    and
    <txt underline underlinestyle="dashed" underlinecolor="blue">dashed</txt>
    underlines.</txt
  >
  <txt monospaceddigit font="title2">12:34</txt>
  <txt font="body"
    >Spans can use <txt fontname="Georgia-Italic">Georgia italic</txt> too.</txt
  >
  <txt fontname="Georgia" size={20} lang="tr">grafik geçmiş</txt>
</vstack>
