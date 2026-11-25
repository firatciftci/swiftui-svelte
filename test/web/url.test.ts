import { describe, expect, it } from "vitest";
import { URLSearchParamsShim, URLShim } from "swiftui-svelte/web/url";
import setters from "./wpt/setters_tests.json" with { type: "json" };
import cases from "./wpt/urltestdata.json" with { type: "json" };

type Case = {
  input: string;
  base: string | null;
  failure?: boolean;
  href?: string;
  origin?: string;
  protocol?: string;
  username?: string;
  password?: string;
  host?: string;
  hostname?: string;
  port?: string;
  pathname?: string;
  search?: string;
  hash?: string;
};

const parsing = (cases as Array<unknown>).filter(
  (entry): entry is Case => typeof entry === "object",
);
const components = [
  "href",
  "protocol",
  "username",
  "password",
  "host",
  "hostname",
  "port",
  "pathname",
  "search",
  "hash",
] as const;

describe("uRL parsing (web-platform-tests)", () => {
  it.each(
    parsing.map(
      (entry) =>
        [
          `${JSON.stringify(entry.input)} against ${String(entry.base)}`,
          entry,
        ] as const,
    ),
  )("%s", (_, entry) => {
    if (entry.failure === true) {
      expect(() => new URLShim(entry.input, entry.base ?? undefined)).toThrow(
        TypeError,
      );
      expect(URLShim.canParse(entry.input, entry.base ?? undefined)).toBe(
        false,
      );
      return;
    }
    const url = new URLShim(entry.input, entry.base ?? undefined);
    for (const key of components) expect(url[key], key).toBe(entry[key]);
    if (entry.origin != null) expect(url.origin).toBe(entry.origin);
    expect(url.searchParams.toString()).toBe(
      new URLSearchParamsShim(url.search).toString(),
    );
  });
});

type Setter = {
  href: string;
  new_value: string;
  expected: Record<string, string>;
};

describe("uRL setters (web-platform-tests)", () => {
  for (const [property, tests] of Object.entries(setters)) {
    if (property === "comment") continue;
    it.each(
      (tests as Array<Setter>).map(
        (test) =>
          [
            `${property} = ${JSON.stringify(test.new_value)} on ${test.href}`,
            test,
          ] as const,
      ),
    )("%s", (_, test) => {
      const url = new URLShim(test.href);
      Reflect.set(url, property, test.new_value);
      for (const [key, value] of Object.entries(test.expected))
        expect(Reflect.get(url, key), key).toBe(value);
    });
  }
});
