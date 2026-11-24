globalThis.queueMicrotask ??= (task) => void Promise.resolve().then(task);

function format(value: unknown) {
  if (typeof value === "string") return value;
  if (value instanceof Error) return value.stack ?? value.message;
  try {
    return JSON.stringify(value) ?? String(value);
  } catch {
    return String(value);
  }
}

if (typeof __nativeLog === "function") {
  for (const level of ["log", "info", "warn", "error", "debug"] as const) {
    console[level] = (...args: Array<unknown>) =>
      __nativeLog(level, args.map(format).join(" "));
  }
}
