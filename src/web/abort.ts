import { DOMExceptionShim, EventShim, EventTargetShim } from "./events.ts";

const reasons = new WeakMap<AbortSignalShim, unknown>();
const constructing = Symbol("constructing");

function abort(signal: AbortSignalShim, reason: unknown): void {
  if (reasons.has(signal)) return;
  reasons.set(
    signal,
    reason === undefined
      ? new DOMExceptionShim("This operation was aborted", "AbortError")
      : reason,
  );
  signal.dispatchEvent(new EventShim("abort"));
}

export class AbortSignalShim extends EventTargetShim {
  static abort(reason?: unknown): AbortSignalShim {
    const signal = new AbortSignalShim(constructing);
    abort(signal, reason);
    return signal;
  }

  static timeout(milliseconds: number): AbortSignalShim {
    const signal = new AbortSignalShim(constructing);
    setTimeout(
      () =>
        abort(
          signal,
          new DOMExceptionShim("The operation timed out", "TimeoutError"),
        ),
      milliseconds,
    );
    return signal;
  }

  static any(
    signals: Iterable<AbortSignal | AbortSignalShim>,
  ): AbortSignalShim {
    const combined = new AbortSignalShim(constructing);
    const sources = [...signals];
    for (const source of sources) {
      if (source.aborted) {
        abort(combined, source.reason);
        return combined;
      }
    }
    for (const source of sources) {
      source.addEventListener("abort", () => abort(combined, source.reason), {
        once: true,
      });
    }
    return combined;
  }

  onabort: ((this: AbortSignalShim, event: EventShim) => unknown) | null = null;

  constructor(key?: typeof constructing) {
    super();
    if (key !== constructing) throw new TypeError("Illegal constructor");
  }

  get aborted(): boolean {
    return reasons.has(this);
  }

  get reason(): unknown {
    return reasons.get(this);
  }

  throwIfAborted(): void {
    if (reasons.has(this)) throw reasons.get(this);
  }
}

export class AbortControllerShim {
  readonly signal = new AbortSignalShim(constructing);

  abort(reason?: unknown): void {
    abort(this.signal, reason);
  }
}
