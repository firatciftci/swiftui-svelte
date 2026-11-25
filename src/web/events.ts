const legacyCodes: Record<string, number> = {
  IndexSizeError: 1,
  HierarchyRequestError: 3,
  WrongDocumentError: 4,
  InvalidCharacterError: 5,
  NoModificationAllowedError: 7,
  NotFoundError: 8,
  NotSupportedError: 9,
  InvalidStateError: 11,
  SyntaxError: 12,
  InvalidModificationError: 13,
  NamespaceError: 14,
  InvalidAccessError: 15,
  TypeMismatchError: 17,
  SecurityError: 18,
  NetworkError: 19,
  AbortError: 20,
  URLMismatchError: 21,
  QuotaExceededError: 22,
  TimeoutError: 23,
  InvalidNodeTypeError: 24,
  DataCloneError: 25,
};

export class DOMExceptionShim extends Error {
  readonly code: number;

  constructor(message = "", name = "Error") {
    super(message);
    Object.defineProperty(this, "name", { value: name, configurable: true });
    this.code = legacyCodes[name] ?? 0;
  }
}

type Listener =
  | { bivarianceHack(event: EventShim): unknown }["bivarianceHack"]
  | { handleEvent(event: EventShim): unknown };
type Registration = {
  listener: Listener;
  capture: boolean;
  once: boolean;
  passive: boolean;
  removed: boolean;
};

const dispatching = new WeakMap<EventShim, { passive: boolean }>();
const stopped = new WeakSet<EventShim>();
const canceled = new WeakSet<EventShim>();
const listeners = new WeakMap<
  EventTargetShim,
  Map<string, Array<Registration>>
>();

export class EventShim {
  static readonly NONE = 0;
  static readonly CAPTURING_PHASE = 1;
  static readonly AT_TARGET = 2;
  static readonly BUBBLING_PHASE = 3;
  readonly NONE = 0;
  readonly CAPTURING_PHASE = 1;
  readonly AT_TARGET = 2;
  readonly BUBBLING_PHASE = 3;

  readonly type: string;
  readonly bubbles: boolean;
  readonly cancelable: boolean;
  readonly composed: boolean;
  readonly timeStamp =
    typeof performance === "undefined" ? 0 : performance.now();
  readonly isTrusted = false;
  target: EventTargetShim | null = null;
  currentTarget: EventTargetShim | null = null;
  eventPhase = 0;
  cancelBubble = false;

  constructor(...[type, init = {}]: [type: string, init?: EventInit]) {
    const value: unknown = type;
    if (value === undefined)
      throw new TypeError('The "type" argument must be specified');
    this.type = type;
    this.bubbles = Boolean(init.bubbles);
    this.cancelable = Boolean(init.cancelable);
    this.composed = Boolean(init.composed);
  }

  get defaultPrevented(): boolean {
    return canceled.has(this);
  }

  get returnValue(): boolean {
    return !canceled.has(this);
  }

  get srcElement(): EventTargetShim | null {
    return this.target;
  }

  composedPath(): Array<EventTargetShim> {
    return this.currentTarget == null ? [] : [this.currentTarget];
  }

  preventDefault(): void {
    if (this.cancelable && dispatching.get(this)?.passive !== true) {
      canceled.add(this);
    }
  }

  stopPropagation(): void {
    this.cancelBubble = true;
  }

  stopImmediatePropagation(): void {
    this.cancelBubble = true;
    stopped.add(this);
  }
}

export class CustomEventShim<T = unknown> extends EventShim {
  readonly detail: T | null;

  constructor(type: string, init: CustomEventInit<T> = {}) {
    super(type, init);
    this.detail = init.detail ?? null;
  }
}

function report(error: unknown): void {
  if (typeof reportError === "function") reportError(error);
  else console.error(error);
}

export class EventTargetShim {
  addEventListener(
    type: string,
    listener: Listener | null,
    options: boolean | AddEventListenerOptions = {},
  ): void {
    if (listener == null) return;
    const settings =
      typeof options === "boolean" ? { capture: options } : options;
    if (settings.signal?.aborted === true) return;
    let byType = listeners.get(this);
    if (byType == null) {
      byType = new Map();
      listeners.set(this, byType);
    }
    let registrations = byType.get(type);
    if (registrations == null) {
      registrations = [];
      byType.set(type, registrations);
    }
    const isCapture = Boolean(settings.capture);
    if (
      registrations.some(
        (entry) => entry.listener === listener && entry.capture === isCapture,
      )
    ) {
      return;
    }
    const registration: Registration = {
      listener,
      capture: isCapture,
      once: Boolean(settings.once),
      passive: Boolean(settings.passive),
      removed: false,
    };
    registrations.push(registration);
    settings.signal?.addEventListener("abort", () =>
      this.removeEventListener(type, listener, { capture: isCapture }),
    );
  }

  removeEventListener(
    type: string,
    listener: Listener | null,
    options: boolean | EventListenerOptions = {},
  ): void {
    const isCapture = Boolean(
      typeof options === "boolean" ? options : options.capture,
    );
    const registrations = listeners.get(this)?.get(type);
    if (registrations == null) return;
    const index = registrations.findIndex(
      (entry) => entry.listener === listener && entry.capture === isCapture,
    );
    if (index === -1) return;
    const [registration] = registrations.splice(index, 1);
    if (registration != null) registration.removed = true;
  }

  dispatchEvent(event: EventShim | Event): boolean {
    if (!(event instanceof EventShim)) {
      throw new TypeError('The "event" argument must be an instance of Event');
    }
    if (dispatching.has(event)) {
      throw new DOMExceptionShim(
        "The event is already being dispatched",
        "InvalidStateError",
      );
    }
    event.target = this;
    event.currentTarget = this;
    event.eventPhase = EventShim.AT_TARGET;
    const registrations = [...(listeners.get(this)?.get(event.type) ?? [])];
    const handler: unknown = Reflect.get(this, `on${event.type}`);
    for (const registration of registrations) {
      if (registration.removed) continue;
      if (registration.once)
        this.removeEventListener(
          event.type,
          registration.listener,
          registration,
        );
      dispatching.set(event, { passive: registration.passive });
      try {
        const { listener } = registration;
        if (typeof listener === "function") listener.call(this, event);
        else listener.handleEvent(event);
      } catch (error) {
        report(error);
      }
      if (stopped.has(event)) break;
    }
    if (typeof handler === "function" && !stopped.has(event)) {
      dispatching.set(event, { passive: false });
      try {
        if (handler.call(this, event) === false) event.preventDefault();
      } catch (error) {
        report(error);
      }
    }
    dispatching.delete(event);
    event.currentTarget = null;
    event.eventPhase = EventShim.NONE;
    return !event.defaultPrevented;
  }
}
