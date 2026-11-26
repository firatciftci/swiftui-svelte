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
  <hstack spacing={16}>
    <txt padding background="orange" radius={8} brightness={0.3}>Brighter</txt>
    <txt padding background="orange" radius={8} lighten={0.125}>Lightened</txt>
    <txt padding background="orange" radius={8} colormultiply="blue">Tinted</txt
    >
    <txt padding background="white" radius={8} blendmode="multiply" color="red"
      >Multiplied</txt
    >
  </hstack>
  <hstack
    spacing={16}
    padding
    background="white"
    radius={12}
    hovered={{ lighten: 0.125 }}
  >
    <txt>Lightened on hover</txt>
    <rectangle background="clear" radius={12} insetshadow />
  </hstack>
  <txt compositinggroup opacity={0.5}>
    <span color="red">Grouped</span> <span color="blue">spans</span>
  </txt>
  <btn variant="prominent" tint="green" controlsize="large">
    Large green button
  </btn>
</vstack>
