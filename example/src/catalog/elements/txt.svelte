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
    >Spans can use <txt fontname="Georgia-Italic">Georgia italic</txt> too.</txt
  >
</vstack>
