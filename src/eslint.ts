const dom = "There's no DOM in a swiftui-svelte app.";
const alert = "Use an alert element instead.";

const unavailable: Record<string, string> = {
  document: `${dom} Use ref() for element refs.`,
  Element: dom,
  HTMLElement: dom,
  Node: dom,
  MutationObserver: dom,
  getComputedStyle: "There's no CSS in a swiftui-svelte app.",
  ResizeObserver: "Use onresize on the element instead.",
  IntersectionObserver: "Use onappear and ondisappear instead.",
  XMLHttpRequest: "Use fetch instead.",
  indexedDB: "Use localStorage, or files from swiftui-svelte/native, instead.",
  history: "Use a navstack and its onpop event instead.",
  location:
    "Use links.open from swiftui-svelte/native to open a URL, and onOpenURL from swiftui-svelte/app to handle one.",
  alert,
  confirm: alert,
  prompt: "Use an alert element with a textfield instead.",
  Worker: "There are no web workers in a swiftui-svelte app.",
};

export const swiftuiSvelte: Array<{
  name: string;
  rules: Record<string, ["error", ...Array<{ name: string; message: string }>]>;
}> = [
  {
    name: "swiftui-svelte/globals",
    rules: {
      "no-restricted-globals": [
        "error",
        ...Object.entries(unavailable).map(([name, message]) => ({
          name,
          message,
        })),
      ],
    },
  },
];
