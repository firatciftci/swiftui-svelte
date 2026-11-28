import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { elements, modifiers } from "swiftui-svelte/known";

function captures(text: string, pattern: RegExp): Array<string> {
  const names: Array<string> = [];
  for (const [, name] of text.matchAll(pattern))
    if (name != null) names.push(name);
  return names;
}

const directory = path.resolve(import.meta.dirname, "../Sources/SvelteSwiftUI");
const files = readdirSync(directory)
  .filter((file) => file.endsWith(".swift"))
  .map((file) => ({
    file,
    text: readFileSync(path.join(directory, file), "utf8"),
  }));
const swift = files.map(({ text }) => text).join("\n");
const quoted = new Set(captures(swift, /"([a-z][\w-]*)"/gi));
const typed = new Set([...modifiers, ...Object.values(elements).flat()]);
const resolvedInJavaScript = new Set(["class"]);
const readByTheParent = new Set(["selfalign", "completion"]);
const readByStateFeedback = new Set(["pressed", "hovered"]);
const dispatchedPerAction = new Set(["ona11yaction"]);
const htmlAndSvgReaders = new Set(["Markup.swift", "Vector.swift"]);
const internal = new Set(["listens"]);

const modifierSet =
  files.find(({ file }) => file === "ModifierSet.swift")?.text ?? "";

function between(start: string, end: string): Set<string> {
  const section = modifierSet.slice(
    modifierSet.indexOf(start),
    modifierSet.indexOf(end),
  );
  return new Set(captures(section, /"([a-z\d]+)"/g));
}

const groupedAttributes = between("byAttribute", "byEvent");
const groupedEvents = between("byEvent", "byAttachment");

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
    for (const { file, text } of files) {
      if (htmlAndSvgReaders.has(file)) continue;
      for (const name of captures(text, /attributes\[\s*"([\w-]+)"\s*\]/g)) {
        if (!typed.has(name) && !internal.has(name)) untyped.add(name);
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
    const unknown: Array<string> = [];
    for (const name of groupedAttributes)
      if (!modifiers.has(name)) unknown.push(name);
    expect(unknown).toEqual([]);
  });
});

describe("the bridge globals", () => {
  const declarations = readFileSync(
    path.resolve(import.meta.dirname, "../src/globals.d.ts"),
    "utf8",
  );
  const declared = new Set(
    captures(declarations, /declare (?:function|var) (__\w+)/g),
  );
  const globals = new Set(captures(swift, /"(__\w+)"/g));
  const named = (prefix: string): Array<string> =>
    [...globals]
      .filter((name) => name.startsWith(prefix))
      .toSorted((a, b) => a.localeCompare(b));

  it("declares every global that Swift installs, and nothing else", () => {
    expect(named("__native")).toEqual(
      [...declared]
        .filter((name) => name.startsWith("__native"))
        .toSorted((a, b) => a.localeCompare(b)),
    );
  });

  it("declares every JavaScript function that Swift calls", () => {
    expect(named("__svelte").filter((name) => !declared.has(name))).toEqual([]);
  });
});
