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

export function generate(): string {
  const { checker, file, elements, modifiers } = load();
  const names = (type: ts.Type): Array<string> => [
    ...new Set(
      (type.isUnion() ? type.types : [type]).flatMap((member) =>
        checker
          .getPropertiesOfType(member)
          .map((property) => property.getName()),
      ),
    ),
  ];
  const shared = new Set(names(checker.getTypeAtLocation(modifiers)));
  const own: Record<string, Array<string>> = {};
  for (const member of elements.members) {
    if (!ts.isPropertySignature(member) || member.type == null) continue;
    const name = member.name.getText(file).replaceAll('"', "");
    own[name] = names(checker.getTypeFromTypeNode(member.type))
      .filter((attribute) => !shared.has(attribute))
      .toSorted((a, b) => a.localeCompare(b));
  }
  const lines = [
    `export const modifiers: ReadonlySet<string> = new Set(${JSON.stringify([...shared].toSorted((a, b) => a.localeCompare(b)))});`,
    "",
    `export const elements: Readonly<Record<string, ReadonlyArray<string>>> = ${JSON.stringify(own)};`,
    "",
  ];
  return lines.join("\n");
}

if (import.meta.main) {
  const { writeFileSync } = await import("node:fs");
  writeFileSync(path.join(root, "src/known.ts"), generate());
}
