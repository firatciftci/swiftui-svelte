export const base = "";
export const assets = "";

const PARAMETER = /\[{1,2}(?:\.{3})?(\w+)(?:=\w+)?\]{1,2}/g;

export function resolve(
  route: string,
  params: Record<string, string | undefined> = {},
): string {
  const segments = route
    .split("/")
    .filter((segment) => !/^\(.+\)$/.test(segment))
    .map((segment) =>
      segment.replaceAll(
        PARAMETER,
        (_match, name: string) => params[name] ?? "",
      ),
    )
    .filter((segment, index) => index === 0 || segment !== "");
  const path = segments.join("/");
  return (
    base + (route.startsWith("/") && !path.startsWith("/") ? `/${path}` : path)
  );
}

export function asset(file: string): string {
  return assets + file;
}
