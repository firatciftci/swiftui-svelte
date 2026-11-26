import { env } from "swiftui-svelte/env";

export type UserPrefersMode = "light" | "dark" | "system";

export type Mode = "light" | "dark";

export const modeStorageKey = "mode-watcher-mode";

const modes: Array<UserPrefersMode> = ["light", "dark", "system"];

class UserPrefersModeState {
  #key = modeStorageKey;
  #fallback: UserPrefersMode = "system";
  #current: UserPrefersMode = $state(this.#stored());

  #stored(): UserPrefersMode {
    const value = localStorage.getItem(this.#key);
    return modes.find((mode) => mode === value) ?? this.#fallback;
  }

  configure(key: string, fallback: UserPrefersMode): void {
    this.#key = key;
    this.#fallback = fallback;
    this.#current = this.#stored();
  }

  get current(): UserPrefersMode {
    return this.#current;
  }

  set current(value: UserPrefersMode) {
    this.#current = value;
    localStorage.setItem(this.#key, value);
  }
}

class SystemPrefersModeState {
  get current(): Mode | undefined {
    return env.systemColorScheme;
  }
}

export const userPrefersMode = new UserPrefersModeState();

export const systemPrefersMode = new SystemPrefersModeState();

export const mode = {
  get current(): Mode | undefined {
    return userPrefersMode.current === "system"
      ? systemPrefersMode.current
      : userPrefersMode.current;
  },
};

export function setMode(value: UserPrefersMode): void {
  userPrefersMode.current = value;
}

export function toggleMode(): void {
  setMode(mode.current === "dark" ? "light" : "dark");
}

export function resetMode(): void {
  setMode("system");
}
