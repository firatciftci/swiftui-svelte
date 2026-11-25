import type { Environment } from "vitest/runtime";

export default {
  name: "native",
  viteEnvironment: "client",
  setup: () => ({ teardown: () => {} }),
} satisfies Environment;
