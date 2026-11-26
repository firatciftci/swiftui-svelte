import { createSubscriber } from "svelte/reactivity";
import type { HostEnvironment } from "./web/environment.ts";
import { environment, observeEnvironment } from "./web/environment.ts";

type Key = keyof HostEnvironment;

const subscribers = new Map<Key, () => void>();

function isSame(left: unknown, right: unknown): boolean {
  return left === right || JSON.stringify(left) === JSON.stringify(right);
}

function read<K extends Key>(key: K): HostEnvironment[K] {
  let subscribe = subscribers.get(key);
  if (subscribe == null) {
    subscribe = createSubscriber((update) =>
      observeEnvironment((previous) => {
        if (!isSame(previous[key], environment[key])) update();
      }),
    );
    subscribers.set(key, subscribe);
  }
  subscribe();
  return environment[key];
}

export type { HostEnvironment as Environment } from "./web/environment.ts";

export const env: Readonly<HostEnvironment> = {
  get colorScheme() {
    return read("colorScheme");
  },
  get reduceMotion() {
    return read("reduceMotion");
  },
  get reduceTransparency() {
    return read("reduceTransparency");
  },
  get increaseContrast() {
    return read("increaseContrast");
  },
  get voiceOver() {
    return read("voiceOver");
  },
  get switchControl() {
    return read("switchControl");
  },
  get differentiateWithoutColor() {
    return read("differentiateWithoutColor");
  },
  get invertColors() {
    return read("invertColors");
  },
  get boldText() {
    return read("boldText");
  },
  get buttonShapes() {
    return read("buttonShapes");
  },
  get dynamicTypeSize() {
    return read("dynamicTypeSize");
  },
  get locale() {
    return read("locale");
  },
  get languages() {
    return read("languages");
  },
  get timeZone() {
    return read("timeZone");
  },
  get layoutDirection() {
    return read("layoutDirection");
  },
  get horizontalSizeClass() {
    return read("horizontalSizeClass");
  },
  get verticalSizeClass() {
    return read("verticalSizeClass");
  },
  get scenePhase() {
    return read("scenePhase");
  },
  get safeAreaInsets() {
    return read("safeAreaInsets");
  },
  get keyboardHeight() {
    return read("keyboardHeight");
  },
  get viewportWidth() {
    return read("viewportWidth");
  },
  get viewportHeight() {
    return read("viewportHeight");
  },
  get pixelRatio() {
    return read("pixelRatio");
  },
  get fontScale() {
    return read("fontScale");
  },
  get platform() {
    return read("platform");
  },
  get idiom() {
    return read("idiom");
  },
  get onLine() {
    return read("onLine");
  },
  get userAgent() {
    return read("userAgent");
  },
};
