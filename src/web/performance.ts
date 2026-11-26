import { DOMExceptionShim } from "./events.ts";

type Entry = {
  name: string;
  entryType: "mark" | "measure";
  startTime: number;
  duration: number;
  detail: unknown;
  toJSON: () => unknown;
};

function entry(
  name: string,
  entryType: "mark" | "measure",
  startTime: number,
  duration: number,
  detail: unknown,
): Entry {
  return {
    name,
    entryType,
    startTime,
    duration,
    detail,
    toJSON: () => ({ name, entryType, startTime, duration, detail }),
  };
}

type MeasureOptions = {
  start?: string | number;
  end?: string | number;
  duration?: number;
  detail?: unknown;
};

type HostPerformance = {
  timeOrigin: number;
  now: () => number;
  mark: (
    name: string,
    options?: { startTime?: number; detail?: unknown },
  ) => Entry;
  measure: (
    name: string,
    start?: string | MeasureOptions,
    end?: string,
  ) => Entry;
  getEntries: () => Array<Entry>;
  getEntriesByName: (name: string, type?: string) => Array<Entry>;
  getEntriesByType: (type: string) => Array<Entry>;
  clearMarks: (name?: string) => void;
  clearMeasures: (name?: string) => void;
  toJSON: () => { timeOrigin: number };
};

export function createPerformance(clock: () => number): HostPerformance {
  const origin = clock();
  const timeOrigin = Date.now();
  let entries: Array<Entry> = [];
  const now = (): number => clock() - origin;
  const resolve = (mark: string | number): number => {
    if (typeof mark === "number") {
      if (mark < 0)
        throw new TypeError(`'${String(mark)}' cannot be negative.`);
      return mark;
    }
    const found = entries.findLast(
      (item) => item.entryType === "mark" && item.name === mark,
    );
    if (found == null)
      throw new DOMExceptionShim(
        `The mark '${mark}' does not exist.`,
        "SyntaxError",
      );
    return found.startTime;
  };
  return {
    timeOrigin,
    now,
    mark(
      name: string,
      options: { startTime?: number; detail?: unknown } = {},
    ): Entry {
      const created = entry(
        name,
        "mark",
        options.startTime ?? now(),
        0,
        options.detail ?? null,
      );
      entries.push(created);
      return created;
    },
    measure(
      name: string,
      start?: string | MeasureOptions,
      end?: string,
    ): Entry {
      let startTime = 0;
      let endTime = now();
      let detail: unknown = null;
      if (start != null && typeof start === "object") {
        const options = start;
        detail = options.detail ?? null;
        if (options.start !== undefined && options.end !== undefined) {
          startTime = resolve(options.start);
          endTime = resolve(options.end);
        } else if (options.start !== undefined) {
          startTime = resolve(options.start);
          endTime =
            options.duration === undefined
              ? now()
              : startTime + options.duration;
        } else if (options.end !== undefined) {
          endTime = resolve(options.end);
          startTime =
            options.duration === undefined ? 0 : endTime - options.duration;
        }
      } else {
        if (start !== undefined) startTime = resolve(start);
        if (end !== undefined) endTime = resolve(end);
      }
      const created = entry(
        name,
        "measure",
        startTime,
        endTime - startTime,
        detail,
      );
      entries.push(created);
      return created;
    },
    getEntries: (): Array<Entry> => [...entries],
    getEntriesByName: (name: string, type?: string): Array<Entry> =>
      entries.filter(
        (item) =>
          item.name === name && (type === undefined || item.entryType === type),
      ),
    getEntriesByType: (type: string): Array<Entry> =>
      entries.filter((item) => item.entryType === type),
    clearMarks(name?: string): void {
      entries = entries.filter(
        (item) =>
          item.entryType !== "mark" ||
          (name !== undefined && item.name !== name),
      );
    },
    clearMeasures(name?: string): void {
      entries = entries.filter(
        (item) =>
          item.entryType !== "measure" ||
          (name !== undefined && item.name !== name),
      );
    },
    toJSON: () => ({ timeOrigin }),
  };
}
