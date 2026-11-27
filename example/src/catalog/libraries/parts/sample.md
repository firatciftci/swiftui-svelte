# Markdown with mdsvex

This screen is a Markdown file. mdsvex compiles it to a Svelte component, and swiftui-svelte draws each HTML tag with a SwiftUI view: **bold**, _italic_, `code`, ~~struck~~, and a [link](https://mdsvex.pngwn.io).

## Lists

- Paragraphs, headings, and quotes
- Ordered and unordered lists
  - Nested lists, too

1. Write the Markdown.
2. Import the file as a component.

> A block quote gets a bar along its leading edge.

```js
import Sample from "./sample.md";
```

---

| Tag     | Drawn as                   |
| ------- | -------------------------- |
| `p`     | Text                       |
| `pre`   | Code that scrolls sideways |
| `table` | Grid                       |
