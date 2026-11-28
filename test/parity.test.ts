import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { elements, modifiers } from "swiftui-svelte/known";

const directory = path.resolve(import.meta.dirname, "../Sources/SvelteSwiftUI");
const sources = new Map(
  readdirSync(directory)
    .filter((file) => file.endsWith(".swift"))
    .map((file) => [file, readFileSync(path.join(directory, file), "utf8")]),
);
const swift = [...sources.values()].join("\n");
const quoted = new Set(
  Array.from(swift.matchAll(/"([A-Za-z][\w-]*)"/g), ([, name]) => name),
);
const typed = new Set([...modifiers, ...Object.values(elements).flat()]);
const resolvedInJavaScript = new Set(["class"]);
const readByTheParent = new Set(["axis", "css", "selfalign", "completion"]);
const readByStateFeedback = new Set(["pressed", "hovered"]);
const dispatchedPerAction = new Set(["ona11yaction"]);
const htmlAndSvgReaders = new Set(["Markup.swift", "Vector.swift"]);
const internal = new Set(["listens"]);

function between(text: string, start: string, end: string): Set<string> {
  const section = text.slice(text.indexOf(start), text.indexOf(end));
  return new Set(
    Array.from(section.matchAll(/"([a-z\d]+)"/g), ([, name]) => name),
  );
}

const modifierSet = sources.get("ModifierSet.swift") ?? "";
const groupedAttributes = between(modifierSet, "byAttribute", "byEvent");
const groupedEvents = between(modifierSet, "byEvent", "byAttachment");

describe("the element schema and the Swift host", () => {
  it("has a Swift reader for every typed attribute", () => {
    const unread = [...typed].filter(
      (name) =>
        !resolvedInJavaScript.has(name) &&
        !quoted.has(name.startsWith("on") ? name.slice(2) : name),
    );
    expect(unread).toEqual([]);
  });

  it("types every attribute that Swift reads", () => {
    const untyped = new Set<string>();
    for (const [file, text] of sources) {
      if (htmlAndSvgReaders.has(file)) continue;
      for (const [, name] of text.matchAll(/attributes\[\s*"([\w-]+)"\s*\]/g)) {
        if (name != null && !typed.has(name) && !internal.has(name))
          untyped.add(name);
      }
    }
    expect([...untyped]).toEqual([]);
  });

  it("puts every shared modifier in a ModifierSet group", () => {
    const ungrouped = [...modifiers].filter((name) =>
      name.startsWith("on")
        ? !groupedEvents.has(name.slice(2)) && !dispatchedPerAction.has(name)
        : !groupedAttributes.has(name) &&
          !resolvedInJavaScript.has(name) &&
          !readByTheParent.has(name) &&
          !readByStateFeedback.has(name),
    );
    expect(ungrouped).toEqual([]);
  });

  it("groups only typed modifiers", () => {
    const unknown = [...groupedAttributes].filter(
      (name) => !modifiers.has(name),
    );
    expect(unknown).toEqual([]);
  });
});

describe("the bridge globals", () => {
  const declarations = readFileSync(
    path.resolve(import.meta.dirname, "../src/globals.d.ts"),
    "utf8",
  );
  const declared = new Set(
    Array.from(
      declarations.matchAll(/declare (?:function|var) (__\w+)/g),
      ([, name]) => name,
    ),
  );
  const globals = new Set(
    Array.from(swift.matchAll(/"(__\w+)"/g), ([, name]) => name),
  );
  const named = (prefix: string): Array<string> =>
    [...globals].filter((name) => name?.startsWith(prefix)).toSorted();

  it("declares every global that Swift installs, and nothing else", () => {
    expect(named("__native")).toEqual(
      [...declared].filter((name) => name?.startsWith("__native")).toSorted(),
    );
  });

  it("declares every JavaScript function that Swift calls", () => {
    expect(named("__svelte").filter((name) => !declared.has(name))).toEqual([]);
  });
});
