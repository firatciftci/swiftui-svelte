import { EventShim, EventTargetShim } from "./events.ts";

type SizeClass = "compact" | "regular";

export type HostEnvironment = {
  colorScheme: "light" | "dark";
  systemColorScheme: "light" | "dark";
  /** Whether the system draws Liquid Glass, as on iOS 26 and later. @platform ios */
  liquidGlass: boolean;
  reduceMotion: boolean;
  reduceTransparency: boolean;
  increaseContrast: boolean;
  voiceOver: boolean;
  switchControl: boolean;
  differentiateWithoutColor: boolean;
  invertColors: boolean;
  boldText: boolean;
  /** Whether the Button Shapes accessibility setting is on. @platform ios */
  buttonShapes: boolean;
  /** SwiftUI's `DynamicTypeSize` case name. For portable code, use `fontScale`. @platform ios */
  dynamicTypeSize:
    | "xSmall"
    | "small"
    | "medium"
    | "large"
    | "xLarge"
    | "xxLarge"
    | "xxxLarge"
    | "accessibility1"
    | "accessibility2"
    | "accessibility3"
    | "accessibility4"
    | "accessibility5";
  locale: string;
  languages: Array<string>;
  timeZone: string;
  layoutDirection: "leftToRight" | "rightToLeft";
  /** SwiftUI's horizontal size class. For portable code, use `viewportWidth`. @platform ios */
  horizontalSizeClass: SizeClass | null;
  /** SwiftUI's vertical size class. For portable code, use `viewportHeight`. @platform ios */
  verticalSizeClass: SizeClass | null;
  /** SwiftUI's scene phase: `active`, `inactive`, or `background`. @platform ios */
  scenePhase: "active" | "inactive" | "background";
  safeAreaInsets: Readonly<{
    top: number;
    leading: number;
    bottom: number;
    trailing: number;
  }>;
  keyboardHeight: number;
  viewportWidth: number;
  viewportHeight: number;
  pixelRatio: number;
  fontScale: number;
  platform: string;
  /** The kind of Apple device: `phone`, `pad`, `tv`, `mac`, or `vision`. @platform ios */
  idiom: string;
  onLine: boolean;
  userAgent: string;
};

export const environment: HostEnvironment = {
  colorScheme: "light",
  systemColorScheme: "light",
  liquidGlass: false,
  reduceMotion: false,
  reduceTransparency: false,
  increaseContrast: false,
  voiceOver: false,
  switchControl: false,
  differentiateWithoutColor: false,
  invertColors: false,
  boldText: false,
  buttonShapes: false,
  dynamicTypeSize: "large",
  locale: "en-US",
  languages: ["en-US"],
  timeZone: "UTC",
  layoutDirection: "leftToRight",
  horizontalSizeClass: null,
  verticalSizeClass: null,
  scenePhase: "active",
  safeAreaInsets: { top: 0, leading: 0, bottom: 0, trailing: 0 },
  keyboardHeight: 0,
  viewportWidth: 0,
  viewportHeight: 0,
  pixelRatio: 1,
  fontScale: 1,
  platform: "unknown",
  idiom: "phone",
  onLine: true,
  userAgent: "swiftui-svelte",
};

const observers = new Set<(previous: HostEnvironment) => void>();

export function observeEnvironment(
  observer: (previous: HostEnvironment) => void,
): () => void {
  observers.add(observer);
  return () => void observers.delete(observer);
}

export function updateEnvironment(changes: Partial<HostEnvironment>): void {
  const previous = { ...environment };
  Object.assign(environment, changes);
  for (const observer of observers) {
    try {
      observer(previous);
    } catch (error) {
      reportError(error);
    }
  }
}

function feature(name: string, value: string | undefined): boolean | null {
  const yes = (expected: string, isOn: boolean): boolean | null =>
    value === undefined || value === expected
      ? isOn
      : value === "no-preference"
        ? !isOn
        : null;
  switch (name) {
    case "prefers-color-scheme": {
      if (value === undefined) return true;
      return value === "light" || value === "dark"
        ? value === environment.systemColorScheme
        : null;
    }
    case "prefers-reduced-motion": {
      return yes("reduce", environment.reduceMotion);
    }
    case "prefers-reduced-transparency": {
      return yes("reduce", environment.reduceTransparency);
    }
    case "prefers-contrast": {
      if (value === "less" || value === "custom") return false;
      return yes("more", environment.increaseContrast);
    }
    case "hover":
    case "any-hover": {
      return value === undefined
        ? false
        : value === "none"
          ? true
          : value === "hover"
            ? false
            : null;
    }
    case "pointer":
    case "any-pointer": {
      return value === undefined || value === "coarse"
        ? true
        : value === "fine" || value === "none"
          ? false
          : null;
    }
    default: {
      return null;
    }
  }
}

function doesQueryMatch(query: string): boolean {
  let text = query.trim().toLowerCase();
  if (text === "") return true;
  let isNegate = false;
  if (text.startsWith("not ")) {
    isNegate = true;
    text = text.slice(4).trim();
  } else if (text.startsWith("only ")) {
    text = text.slice(5).trim();
  }
  let isResult = true;
  for (const part of text.split(/\s+and\s+/)) {
    const term = part.trim();
    if (term === "all" || term === "screen") continue;
    if (term === "print") {
      isResult = false;
      continue;
    }
    const match = /^\(\s*([a-z-]+)\s*(?::\s*([a-z0-9-]+)\s*)?\)$/.exec(term);
    if (match == null) return false;
    const value = feature(match[1] ?? "", match[2]);
    if (value == null) return false;
    if (!value) isResult = false;
  }
  return isNegate ? !isResult : isResult;
}

function doesMediaMatch(media: string): boolean {
  if (media.trim() === "") return true;
  return media.split(",").some((query) => doesQueryMatch(query));
}

export class MediaQueryListEventShim extends EventShim {
  readonly matches: boolean;
  readonly media: string;

  constructor(
    type: string,
    init: { matches?: boolean; media?: string } & EventInit = {},
  ) {
    super(type, init);
    this.matches = Boolean(init.matches);
    this.media = init.media ?? "";
  }
}

const watched = new Map<MediaQueryListShim, number>();

export class MediaQueryListShim extends EventTargetShim {
  #last: boolean;
  #handler: ((event: MediaQueryListEventShim) => unknown) | null = null;
  readonly media: string;

  constructor(media: string) {
    super();
    this.media = media.trim().replaceAll(/\s+/g, " ").toLowerCase();
    this.#last = doesMediaMatch(this.media);
  }

  #watch(delta: number): void {
    const count = (watched.get(this) ?? 0) + delta;
    if (count > 0) watched.set(this, count);
    else watched.delete(this);
  }

  get matches(): boolean {
    return doesMediaMatch(this.media);
  }

  get onchange(): ((event: MediaQueryListEventShim) => unknown) | null {
    return this.#handler;
  }

  set onchange(handler: ((event: MediaQueryListEventShim) => unknown) | null) {
    if (handler != null && this.#handler == null) this.#watch(1);
    if (handler == null && this.#handler != null) this.#watch(-1);
    this.#handler = handler;
  }

  override addEventListener(
    ...args: Parameters<EventTargetShim["addEventListener"]>
  ): void {
    if (args[0] === "change" && args[1] != null) this.#watch(1);
    super.addEventListener(...args);
  }

  override removeEventListener(
    ...args: Parameters<EventTargetShim["removeEventListener"]>
  ): void {
    if (args[0] === "change" && args[1] != null) this.#watch(-1);
    super.removeEventListener(...args);
  }

  addListener(
    listener: ((event: MediaQueryListEventShim) => void) | null,
  ): void {
    this.addEventListener("change", listener);
  }

  removeListener(
    listener: ((event: MediaQueryListEventShim) => void) | null,
  ): void {
    this.removeEventListener("change", listener);
  }

  refresh(): void {
    const isMatches = doesMediaMatch(this.media);
    if (isMatches === this.#last) return;
    this.#last = isMatches;
    this.dispatchEvent(
      new MediaQueryListEventShim("change", {
        matches: isMatches,
        media: this.media,
      }),
    );
  }
}

observeEnvironment(() => {
  for (const list of watched.keys()) list.refresh();
});

export function matchMediaShim(media: string): MediaQueryListShim {
  return new MediaQueryListShim(media);
}

type HostNavigator = {
  readonly language: string;
  readonly languages: ReadonlyArray<string>;
  readonly onLine: boolean;
  readonly userAgent: string;
  readonly hardwareConcurrency: number;
  readonly cookieEnabled: boolean;
};

export function createNavigator(): HostNavigator {
  return {
    get language(): string {
      return environment.languages[0] ?? "en-US";
    },
    get languages(): ReadonlyArray<string> {
      return Object.freeze([...environment.languages]);
    },
    get onLine(): boolean {
      return environment.onLine;
    },
    get userAgent(): string {
      return environment.userAgent;
    },
    get hardwareConcurrency(): number {
      return 1;
    },
    get cookieEnabled(): boolean {
      return false;
    },
  };
}
