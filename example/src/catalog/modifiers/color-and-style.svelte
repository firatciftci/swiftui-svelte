<vstack spacing={16} padding>
  <txt
    font="title"
    weight="bold"
    color={{ linear: ["pink", "purple"], start: "leading", end: "trailing" }}
  >
    Gradient text
  </txt>
  <txt
    padding
    background="yellow"
    radius={8}
    border={{ color: "orange", width: 2 }}>Bordered</txt
  >
  <txt
    padding
    background="systemBackground"
    radius={12}
    shadow={{ color: "#00000033", radius: 8, y: 4 }}>Shadow</txt
  >
  <hstack spacing={16}>
    <txt opacity={0.4}>Faded</txt>
    <txt blur={2}>Blurred</txt>
  </hstack>
  <btn variant="prominent" tint="green" controlsize="large">
    Large green button
  </btn>
</vstack>
