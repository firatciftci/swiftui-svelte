import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import process from "node:process";

type Manifest = {
  version: string;
  peerDependencies: Record<string, string>;
  devDependencies: Record<string, string>;
};

const root = path.resolve(import.meta.dirname, "..");

const tools = [
  "@sveltejs/vite-plugin-svelte",
  "eslint",
  "eslint-plugin-svelte",
  "svelte-check",
  "typescript",
  "typescript-eslint",
  "vite",
];

function manifest(): Manifest {
  return JSON.parse(
    readFileSync(path.join(root, "package.json"), "utf8"),
  ) as Manifest;
}

function range(version: string): string {
  return /^\d/.test(version) ? `^${version}` : version;
}

export function names(directory: string): {
  app: string;
  packageName: string;
  bundleID: string;
} {
  const base = path.basename(path.resolve(directory));
  const words = base.split(/[^a-z0-9]+/i).filter((word) => word !== "");
  const joined = words
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join("")
    .replace(/^\d+/, "");
  const app = joined === "" ? "App" : joined;
  const packageName =
    base
      .toLowerCase()
      .replaceAll(/[^a-z0-9._~-]+/g, "-")
      .replace(/^[._-]+/, "") || "app";
  return { app, packageName, bundleID: `com.example.${app.toLowerCase()}` };
}

function copy(
  source: string,
  target: string,
  replacements: Array<[string, string]>,
): void {
  const replace = (text: string): string => {
    let result = text;
    for (const [placeholder, value] of replacements) {
      result = result.split(placeholder).join(value);
    }
    return result;
  };
  mkdirSync(target, { recursive: true });
  const entries = readdirSync(source, { withFileTypes: true });
  for (const entry of entries) {
    const name = replace(
      entry.name === "_gitignore" ? ".gitignore" : entry.name,
    );
    const from = path.join(source, entry.name);
    const to = path.join(target, name);
    if (entry.isDirectory()) copy(from, to, replacements);
    else writeFileSync(to, replace(readFileSync(from, "utf8")));
  }
}

export function create(directory: string): { app: string; target: string } {
  const target = path.resolve(directory);
  if (existsSync(target) && readdirSync(target).length > 0) {
    throw new Error(`${directory} isn't empty. Pick a new folder for the app.`);
  }
  const { version, peerDependencies, devDependencies } = manifest();
  const { app, packageName, bundleID } = names(directory);
  copy(path.join(root, "template"), target, [
    ["__APP_NAME__", app],
    ["__BUNDLE_ID__", bundleID],
    ["99.99.99", version],
  ]);
  const dependencies: Record<string, string> = {
    "swiftui-svelte": `^${version}`,
    svelte: peerDependencies.svelte ?? "~5.59.0",
  };
  for (const tool of tools) {
    const toolVersion = devDependencies[tool];
    if (toolVersion != null) dependencies[tool] = range(toolVersion);
  }
  const sorted = Object.fromEntries(
    Object.entries(dependencies).toSorted(([a], [b]) => a.localeCompare(b)),
  );
  const pkg = {
    name: packageName,
    private: true,
    type: "module",
    scripts: {
      dev: "vite build --watch",
      serve: "vite --host",
      build: "vite build",
      check: "svelte-check",
      lint: "eslint .",
    },
    devDependencies: sorted,
  };
  writeFileSync(
    path.join(target, "package.json"),
    `${JSON.stringify(pkg, null, 2)}\n`,
  );
  return { app, target };
}

export function run(args: Array<string>): void {
  const [command, directory = "my-app"] = args;
  if (command !== "create") {
    console.warn("Usage: swiftui-svelte create [folder]");
    process.exitCode = 1;
    return;
  }
  try {
    const { app } = create(directory);
    const lines = [
      `Created ${app} in ${directory}.`,
      "",
      "Next steps:",
      `  cd ${directory}`,
      "  npm install",
      "  npm run build",
      `  open ios/${app}.xcodeproj`,
      "",
      "Run npm run dev while you work, and the simulator reloads when you save.",
    ];
    process.stdout.write(`${lines.join("\n")}\n`);
  } catch (error) {
    console.warn(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
