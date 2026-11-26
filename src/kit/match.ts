export type Params = Record<string, string | undefined>;

export type Matcher = (value: string) => boolean;

export type Matchers = Record<string, Matcher>;

export type Segment =
  | { kind: "static"; value: string }
  | {
      kind: "param";
      name: string;
      matcher: string | null;
      optional: boolean;
      rest: boolean;
    };

const dynamic = /^\[(\[|\.\.\.)?(\w+)(?:=(\w+))?\]\]?$/;

function decode(segment: string): string {
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}

function parseSegment(part: string): Segment {
  const groups = dynamic.exec(part);
  const name = groups?.[2];
  if (groups == null || name == null) return { kind: "static", value: part };
  const modifier = groups[1];
  return {
    kind: "param",
    name,
    matcher: groups[3] ?? null,
    optional: modifier === "[",
    rest: modifier === "...",
  };
}

export function parseSegments(id: string): Array<Segment> {
  return id
    .split("/")
    .filter((part) => part !== "")
    .map((part) => parseSegment(part));
}

function rank(segment: Segment): number {
  if (segment.kind === "static") return 0;
  if (segment.rest) return 4;
  if (segment.optional) return 3;
  return segment.matcher == null ? 2 : 1;
}

export function compareSegments(
  left: Array<Segment>,
  right: Array<Segment>,
): number {
  for (const [index, segment] of left.entries()) {
    const other = right[index];
    if (other == null) return 1;
    const difference = rank(segment) - rank(other);
    if (difference !== 0) return difference;
  }
  return left.length - right.length;
}

function matchSegment(
  segment: Segment,
  parts: Array<string>,
  index: number,
  matchers: Matchers,
  params: Params,
): number | null {
  if (segment.kind === "static") {
    return parts[index] === segment.value ? index + 1 : null;
  }
  if (segment.rest) {
    params[segment.name] = parts.slice(index).join("/");
    return parts.length;
  }
  const part = parts[index];
  if (part == null) {
    if (!segment.optional) return null;
    params[segment.name] = undefined;
    return index;
  }
  if (segment.matcher != null && !matchers[segment.matcher]?.(part))
    return null;
  params[segment.name] = part;
  return index + 1;
}

export function matchSegments(
  segments: Array<Segment>,
  pathname: string,
  matchers: Matchers,
): Params | null {
  const parts = pathname
    .split("/")
    .filter((part) => part !== "")
    .map((part) => decode(part));
  const params: Params = {};
  let index = 0;
  for (const segment of segments) {
    const next = matchSegment(segment, parts, index, matchers, params);
    if (next == null) return null;
    index = next;
  }
  return index === parts.length ? params : null;
}

export function resolveRoute<Route extends { segments: Array<Segment> }>(
  routes: Array<Route>,
  pathname: string,
  matchers: Matchers,
): { route: Route; params: Params } | null {
  for (const route of routes) {
    const params = matchSegments(route.segments, pathname, matchers);
    if (params != null) return { route, params };
  }
  return null;
}
