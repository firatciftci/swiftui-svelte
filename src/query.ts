import { onActive, onBackground } from "./app.ts";

type FocusManagerLike = {
  setEventListener: (
    setup: (
      setFocused: (isFocused?: boolean) => void,
    ) => (() => void) | undefined,
  ) => void;
};

type OnlineManagerLike = {
  setEventListener: (
    setup: (setOnline: (isOnline: boolean) => void) => (() => void) | undefined,
  ) => void;
};

export function connectQueryManagers({
  focusManager,
  onlineManager,
}: {
  focusManager: FocusManagerLike;
  onlineManager: OnlineManagerLike;
}): void {
  focusManager.setEventListener((setFocused) => {
    const stopActive = onActive(() => setFocused(true));
    const stopBackground = onBackground(() => setFocused(false));
    return () => {
      stopActive();
      stopBackground();
    };
  });
  onlineManager.setEventListener((setOnline) => {
    const update = (): void => setOnline(navigator.onLine);
    update();
    addEventListener("online", update);
    addEventListener("offline", update);
    return () => {
      removeEventListener("online", update);
      removeEventListener("offline", update);
    };
  });
}
