import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import ts from "typescript";
import { modifierGroups, sections } from "../example/src/catalog/sections.ts";
import { load } from "./elements.ts";

const root = path.resolve(import.meta.dirname, "..");
const catalog = path.join(root, "example/src/catalog");
const printer = ts.createPrinter({ removeComments: true });

type Attribute = { name: string; types: Array<string>; doc: string };
type Entry = { doc: string; own: Array<Attribute>; isModified: boolean };

function cell(text: string): string {
  return text
    .replaceAll(/\s+/g, " ")
    .trim()
    .replaceAll("|", String.raw`\|`);
}

function union(types: Array<string>): string {
  if (types.length === 1) return types[0] ?? "";
  return types
    .map((type) =>
      type.startsWith("(") && type.includes("=>") ? `(${type})` : type,
    )
    .join(" | ");
}

function table(attributes: Array<Attribute>): Array<string> {
  return [
    "| Attribute | Type | Description |",
    "| --- | --- | --- |",
    ...attributes.map(
      (attribute) =>
        `| \`${attribute.name}\` | \`${cell(union(attribute.types))}\` | ${cell(attribute.doc)} |`,
    ),
  ];
}

function example(folder: string, name: string, uses: Array<string>): string {
  const file = path.join(catalog, folder, `${name}.svelte`);
  const source = readFileSync(file, "utf8").trim();
  for (const used of uses) {
    if (!new RegExp(String.raw`[\s{<]${used}[\s=/>}]`).test(source))
      throw new Error(`${path.relative(root, file)} doesn't use ${used}.`);
  }
  return ["```svelte", source, "```"].join("\n");
}

function anchor(title: string): string {
  return title
    .toLowerCase()
    .replaceAll(/[^a-z0-9 -]/g, "")
    .replaceAll(" ", "-");
}

function checkListed(
  kind: string,
  known: Array<string>,
  listed: Array<string>,
): void {
  const missing = known.filter((name) => !listed.includes(name));
  const unknown = listed.filter((name) => !known.includes(name));
  if (
    missing.length === 0 &&
    unknown.length === 0 &&
    new Set(listed).size === listed.length
  )
    return;
  throw new Error(
    `List every ${kind} in example/src/catalog/sections.ts once. Missing: ${missing.join(", ") || "none"}. Unknown: ${unknown.join(", ") || "none"}.`,
  );
}

class Reader {
  private readonly aliases = new Map<string, ts.TypeAliasDeclaration>();
  private readonly checker: ts.TypeChecker;
  private readonly file: ts.SourceFile;
  readonly referenced = new Set<string>();

  constructor(
    checker: ts.TypeChecker,
    file: ts.SourceFile,
    modifiers: ts.TypeAliasDeclaration,
  ) {
    this.checker = checker;
    this.file = file;
    for (const statement of file.statements) {
      if (statement !== modifiers && ts.isTypeAliasDeclaration(statement))
        this.aliases.set(statement.name.text, statement);
    }
  }

  private body(name: string, alias: ts.TypeAliasDeclaration): string {
    if (!alias.type.getText(this.file).includes("["))
      return alias.getText(this.file).replace(/^export /, "");
    const type = this.checker.getTypeFromTypeNode(alias.type);
    const text = this.checker.typeToString(
      type,
      undefined,
      ts.TypeFormatFlags.NoTruncation,
    );
    return `type ${name} = ${text};`;
  }

  private add(found: Array<Attribute>, property: ts.Symbol): void {
    const declaration = property.declarations?.[0];
    if (
      declaration == null ||
      !ts.isPropertySignature(declaration) ||
      declaration.type == null
    )
      return;
    this.collect(declaration.type);
    const nodes = ts.isUnionTypeNode(declaration.type)
      ? [...declaration.type.types]
      : [declaration.type];
    const types = nodes
      .map((node) =>
        printer.printNode(ts.EmitHint.Unspecified, node, this.file),
      )
      .filter((text) => text !== "undefined");
    const name = property.getName();
    const description = this.doc(property);
    const known = found.find((attribute) => attribute.name === name);
    if (known == null) {
      found.push({ name, types, doc: description });
      return;
    }
    for (const text of types) {
      if (!known.types.includes(text)) known.types.push(text);
    }
    if (!known.doc.includes(description))
      known.doc = `${known.doc} ${description}`;
  }

  private collect(node: ts.Node): void {
    if (ts.isTypeReferenceNode(node)) {
      const name = node.typeName.getText(this.file);
      const alias = this.aliases.get(name);
      if (alias != null && !this.referenced.has(name)) {
        this.referenced.add(name);
        this.collect(alias.type);
      }
    }
    ts.forEachChild(node, (child) => {
      this.collect(child);
    });
  }

  doc(symbol: ts.Symbol | undefined): string {
    if (symbol == null) return "";
    const text = ts.displayPartsToString(
      symbol.getDocumentationComment(this.checker),
    );
    const isIOS = symbol
      .getJsDocTags(this.checker)
      .some(
        (tag) =>
          tag.name === "platform" &&
          ts.displayPartsToString(tag.text).trim() === "ios",
      );
    return isIOS ? `${text} _iOS-specific._` : text;
  }

  attributes(type: ts.Type): Array<Attribute> {
    const found: Array<Attribute> = [];
    const members = type.isUnion() ? type.types : [type];
    for (const member of members) {
      for (const property of this.checker.getPropertiesOfType(member))
        this.add(found, property);
    }
    return found;
  }

  aliasSections(): Array<string> {
    const names = [...this.referenced].toSorted((a, b) => a.localeCompare(b));
    return names.flatMap((name) => {
      const alias = this.aliases.get(name);
      if (alias == null) return [];
      const description = this.doc(
        this.checker.getSymbolAtLocation(alias.name),
      );
      return [
        "",
        `### \`${name}\``,
        ...(description === "" ? [] : ["", description]),
        "",
        "```ts",
        this.body(name, alias),
        "```",
      ];
    });
  }
}

function elementSection(name: string, entry: Entry): Array<string> {
  return [
    "",
    `### \`${name}\``,
    "",
    entry.doc,
    "",
    ...(entry.own.length === 0
      ? ["This element has no attributes of its own."]
      : table(entry.own)),
    ...(entry.isModified ? [] : ["", "This element doesn't take modifiers."]),
    "",
    example("elements", name, [name]),
  ];
}

function read(): {
  entries: Map<string, Entry>;
  shared: Array<Attribute>;
  reader: Reader;
} {
  const { checker, file, elements, modifiers } = load();
  const reader = new Reader(checker, file, modifiers);
  const shared = reader.attributes(checker.getTypeAtLocation(modifiers));
  const modifierNames = shared.map((attribute) => attribute.name);
  const entries = new Map<string, Entry>();
  const names: Array<string> = [];
  for (const member of elements.members) {
    if (!ts.isPropertySignature(member) || member.type == null) continue;
    const all = reader.attributes(checker.getTypeFromTypeNode(member.type));
    const own = all.filter(
      (attribute) => !modifierNames.includes(attribute.name),
    );
    const name = member.name.getText(file).replaceAll('"', "");
    names.push(name);
    entries.set(name, {
      doc: reader.doc(checker.getSymbolAtLocation(member.name)),
      own,
      isModified: all.length - own.length === modifierNames.length,
    });
  }
  checkListed(
    "element",
    names,
    sections.flatMap((section) => section.elements),
  );
  checkListed(
    "modifier",
    modifierNames,
    modifierGroups.flatMap((group) => group.modifiers),
  );
  return { entries, shared, reader };
}

export function generate(): string {
  const { entries, shared, reader } = read();
  const contents = sections.map((section) => {
    const links = section.elements.map((name) => `[\`${name}\`](#${name})`);
    return `- [${section.title}](#${anchor(section.title)}): ${links.join(", ")}`;
  });
  const groups = modifierGroups.map(
    (group) => `[${group.title.toLowerCase()}](#${anchor(group.title)})`,
  );
  return [
    "# Element reference",
    "",
    "This page lists every element and modifier in swiftui-svelte, with the type of each attribute and an example. A script generates it from the TSDoc in [`src/elements.ts`](../src/elements.ts) and the examples in [`example/src/catalog`](../example/src/catalog), which the example app shows in its Catalog tab. To change the page, edit those files and run `nr docs`.",
    "",
    "Every element also takes the [modifiers](#modifiers), unless its entry says it doesn't.",
    "",
    "Descriptions that end in _iOS-specific_ use iOS names or features, so a host for another platform might not support them.",
    "",
    ...contents,
    `- [Modifiers](#modifiers): ${groups.join(", ")}`,
    "- [Value types](#value-types)",
    ...sections.flatMap((section) => [
      "",
      `## ${section.title}`,
      ...section.elements.flatMap((name) => {
        const entry = entries.get(name);
        return entry == null ? [] : elementSection(name, entry);
      }),
    ]),
    "",
    "## Modifiers",
    "",
    "Every element takes these attributes, except the few whose entries say they don't. They're grouped by what they do, and each group ends with an example.",
    ...modifierGroups.flatMap((group) => [
      "",
      `### ${group.title}`,
      "",
      ...(group.modifiers.length === 0
        ? []
        : [
            ...table(
              group.modifiers.flatMap((name) =>
                shared.filter((attribute) => attribute.name === name),
              ),
            ),
            "",
          ]),
      example("modifiers", group.name, group.modifiers),
    ]),
    "",
    "## Value types",
    "",
    "The attribute types above refer to these types from `src/elements.ts`.",
    ...reader.aliasSections(),
    "",
  ].join("\n");
}

if (import.meta.main)
  writeFileSync(path.join(root, "docs/reference.md"), generate());
