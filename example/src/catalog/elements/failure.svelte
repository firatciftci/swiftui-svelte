<asyncimage src="https://example.invalid/photo.jpg" width={120} height={120}>
  <failure>
    <vstack spacing={4}>
      <sfsymbol
        name="photo.badge.exclamationmark"
        font="title"
        color="secondary"
      />
      <txt font="caption" color="secondary">Couldn't load the photo</txt>
    </vstack>
  </failure>
</asyncimage>
