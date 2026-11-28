import { DOMExceptionShim, EventShim, EventTargetShim } from "./events.ts";

const reasons = new WeakMap<AbortSignalShim, unknown>();
const constructing = Symbol("constructing");
const released = new FinalizationRegistry<() => void>((detach) => detach());

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
    const done = sources.find((source) => source.aborted);
    if (done != null) {
      abort(combined, done.reason);
      return combined;
    }
    const target = new WeakRef(combined);
    const listeners: Array<() => void> = [];
    const detach = (): void => {
      for (const [index, source] of sources.entries()) {
        const listener = listeners[index];
        if (listener != null) source.removeEventListener("abort", listener);
      }
    };
    for (const source of sources) {
      const listener = (): void => {
        detach();
        const signal = target.deref();
        if (signal != null) abort(signal, source.reason);
      };
      listeners.push(listener);
      source.addEventListener("abort", listener, { once: true });
    }
    released.register(combined, detach);
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
