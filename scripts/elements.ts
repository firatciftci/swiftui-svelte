import path from "node:path";
import ts from "typescript";

const root = path.resolve(import.meta.dirname, "..");
const source = path.join(root, "src/elements.ts");

function declarations(file: ts.SourceFile): {
  elements: ts.InterfaceDeclaration;
  modifiers: ts.TypeAliasDeclaration;
} {
  let elements: ts.InterfaceDeclaration | undefined;
  let modifiers: ts.TypeAliasDeclaration | undefined;
  const visit = (node: ts.Node): void => {
    if (
      ts.isInterfaceDeclaration(node) &&
      node.name.text === "SvelteHTMLElements"
    )
      elements = node;
    if (ts.isTypeAliasDeclaration(node) && node.name.text === "Modifiers")
      modifiers = node;
    ts.forEachChild(node, visit);
  };
  visit(file);
  if (elements == null || modifiers == null)
    throw new Error("src/elements.ts changed shape.");
  return { elements, modifiers };
}

export function load(): {
  checker: ts.TypeChecker;
  file: ts.SourceFile;
  elements: ts.InterfaceDeclaration;
  modifiers: ts.TypeAliasDeclaration;
} {
  const program = ts.createProgram([source], {
    strict: true,
    noEmit: true,
    target: ts.ScriptTarget.ES2023,
    module: ts.ModuleKind.ESNext,
    moduleResolution: ts.ModuleResolutionKind.Bundler,
    allowImportingTsExtensions: true,
  });
  const checker = program.getTypeChecker();
  const file = program.getSourceFile(source);
  if (file == null) throw new Error("Couldn't read src/elements.ts.");
  return { checker, file, ...declarations(file) };
}

function variants(type: ts.Type): ReadonlyArray<ts.Type> {
  return type.isUnion() ? type.types : [type];
}

function literals(type: ts.Type): Array<string> | null {
  const found: Array<string> = [];
  for (const member of variants(type)) {
    if (member.isStringLiteral()) found.push(member.value);
    else if (
      (member.flags &
        (ts.TypeFlags.String |
          ts.TypeFlags.TemplateLiteral |
          ts.TypeFlags.StringMapping |
          ts.TypeFlags.Intersection |
          ts.TypeFlags.Any |
          ts.TypeFlags.Unknown)) !==
      0
    )
      return null;
  }
  return found.length > 0 ? found : null;
}

export function generate(): string {
  const { checker, file, elements, modifiers } = load();
  const names = (type: ts.Type): Array<string> => [
    ...new Set(
      variants(type).flatMap((member) =>
        checker
          .getPropertiesOfType(member)
          .map((property) => property.getName()),
      ),
    ),
  ];
  const valuesOf = (
    type: ts.Type,
    node: ts.Node,
  ): Record<string, Array<string>> => {
    const found = new Map<string, Set<string> | null>();
    for (const member of variants(type)) {
      for (const property of checker.getPropertiesOfType(member)) {
        const name = property.getName();
        const allowed = literals(
          checker.getNonNullableType(
            checker.getTypeOfSymbolAtLocation(property, node),
          ),
        );
        const previous = found.get(name);
        if (allowed == null || previous === null) found.set(name, null);
        else found.set(name, new Set([...(previous ?? []), ...allowed]));
      }
    }
    const table: Record<string, Array<string>> = {};
    for (const [name, allowed] of found) {
      if (allowed != null) table[name] = [...allowed];
    }
    return table;
  };
  const modifierType = checker.getTypeAtLocation(modifiers);
  const shared = new Set(names(modifierType));
  const sharedValues = valuesOf(modifierType, modifiers);
  const own: Record<string, Array<string>> = {};
  const ownValues: Record<string, Record<string, Array<string>>> = {};
  for (const member of elements.members) {
    if (!ts.isPropertySignature(member) || member.type == null) continue;
    const name = member.name.getText(file).replaceAll('"', "");
    const type = checker.getTypeFromTypeNode(member.type);
    own[name] = names(type)
      .filter((attribute) => !shared.has(attribute))
      .toSorted((a, b) => a.localeCompare(b));
    const values = Object.entries(valuesOf(type, member)).filter(
      ([attribute, allowed]) =>
        JSON.stringify(allowed) !== JSON.stringify(sharedValues[attribute]),
    );
    if (values.length > 0) ownValues[name] = Object.fromEntries(values);
  }
  const lines = [
    `export const modifiers: ReadonlySet<string> = new Set(${JSON.stringify([...shared].toSorted((a, b) => a.localeCompare(b)))});`,
    "",
    `export const elements: Readonly<Record<string, ReadonlyArray<string>>> = ${JSON.stringify(own)};`,
    "",
    `export const modifierValues: Readonly<Record<string, ReadonlyArray<string>>> = ${JSON.stringify(sharedValues)};`,
    "",
    `export const elementValues: Readonly<Record<string, Readonly<Record<string, ReadonlyArray<string>>>>> = ${JSON.stringify(ownValues)};`,
    "",
  ];
  return lines.join("\n");
}

function hasColorForm(type: ts.Type): boolean {
  return variants(type).some(
    (member) =>
      (member.flags & ts.TypeFlags.TemplateLiteral) !== 0 &&
      (member as ts.TemplateLiteralType).texts[0] === "#",
  );
}

export function colorAttributes(): Array<string> {
  const { checker, elements, modifiers } = load();
  const found = new Set<string>();
  const collect = (type: ts.Type, node: ts.Node): void => {
    for (const member of variants(type)) {
      for (const property of checker.getPropertiesOfType(member)) {
        const value = checker.getNonNullableType(
          checker.getTypeOfSymbolAtLocation(property, node),
        );
        if (hasColorForm(value)) found.add(property.getName());
      }
    }
  };
  collect(checker.getTypeAtLocation(modifiers), modifiers);
  for (const member of elements.members) {
    if (ts.isPropertySignature(member) && member.type != null)
      collect(checker.getTypeFromTypeNode(member.type), member);
  }
  return [...found].toSorted((a, b) => a.localeCompare(b));
}

if (import.meta.main) {
  const { writeFileSync } = await import("node:fs");
  writeFileSync(path.join(root, "src/known.ts"), generate());
}
