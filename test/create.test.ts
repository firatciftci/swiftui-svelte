import { mkdtempSync, readdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { create, names } from "swiftui-svelte/create";

function files(directory: string): Array<string> {
  return readdirSync(directory, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) =>
      path.relative(directory, path.join(entry.parentPath, entry.name)),
    )
    .toSorted((a, b) => a.localeCompare(b));
}

describe("the app template", () => {
  it("names the app, the package, and the bundle after the folder", () => {
    expect(names("my-first app")).toEqual({
      app: "MyFirstApp",
      packageName: "my-first-app",
      bundleID: "com.example.myfirstapp",
    });
    expect(names("42")).toEqual({
      app: "App",
      packageName: "42",
      bundleID: "com.example.app",
    });
  });

  it("creates a Svelte app with an Xcode project", () => {
    const parent = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-"));
    const directory = path.join(parent, "weather-app");
    const { app } = create(directory);
    expect(app).toBe("WeatherApp");
    expect(files(directory)).toEqual([
      ".gitignore",
      "eslint.config.js",
      "ios/project.yml",
      "ios/WeatherApp.xcodeproj/project.pbxproj",
      "ios/WeatherApp.xcodeproj/project.xcworkspace/contents.xcworkspacedata",
      "ios/WeatherApp/Assets.xcassets/AccentColor.colorset/Contents.json",
      "ios/WeatherApp/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "ios/WeatherApp/Assets.xcassets/Contents.json",
      "ios/WeatherApp/Info.plist",
      "ios/WeatherApp/JavaScript/.gitkeep",
      "ios/WeatherApp/MainApp.swift",
      "package.json",
      "src/App.svelte",
      "src/main.ts",
      "svelte.config.js",
      "tsconfig.json",
      "vite.config.ts",
    ]);
    for (const file of files(directory)) {
      const text = readFileSync(path.join(directory, file), "utf8");
      expect(text, file).not.toMatch(/__APP_NAME__|__BUNDLE_ID__|99\.99\.99/);
    }
    const project = readFileSync(
      path.join(directory, "ios/WeatherApp.xcodeproj/project.pbxproj"),
      "utf8",
    );
    const { version } = JSON.parse(readFileSync("package.json", "utf8")) as {
      version: string;
    };
    expect(project).toContain(`minimumVersion = ${version};`);
    expect(project).toContain(
      "PRODUCT_BUNDLE_IDENTIFIER = com.example.weatherapp;",
    );
    const manifest = JSON.parse(
      readFileSync(path.join(directory, "package.json"), "utf8"),
    ) as { name: string; devDependencies: Record<string, string> };
    expect(manifest.name).toBe("weather-app");
    expect(manifest.devDependencies["swiftui-svelte"]).toBe(`^${version}`);
    expect(Object.keys(manifest.devDependencies)).toEqual([
      "@sveltejs/vite-plugin-svelte",
      "eslint",
      "eslint-plugin-svelte",
      "svelte",
      "svelte-check",
      "swiftui-svelte",
      "typescript",
      "typescript-eslint",
      "vite",
    ]);
  });

  it("won't write into a folder that has files", () => {
    expect(() => create("src")).toThrow(
      "src isn't empty. Pick a new folder for the app.",
    );
  });
});
