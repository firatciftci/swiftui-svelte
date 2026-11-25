import type { Locale } from "./paraglide/runtime.js";
import {
  getLocale,
  getTextDirection,
  isLocale,
  overwriteGetLocale,
} from "./paraglide/runtime.js";

type Choice = Locale | "system";

const device = getLocale();
const stored = localStorage.getItem("language");
const selection = $state<{ choice: Choice }>({
  choice: stored != null && isLocale(stored) ? stored : "system",
});

overwriteGetLocale(() =>
  selection.choice === "system" ? device : selection.choice,
);

export const language = {
  get choice(): Choice {
    return selection.choice;
  },
  set choice(next: Choice) {
    selection.choice = next;
    if (next === "system") localStorage.removeItem("language");
    else localStorage.setItem("language", next);
  },
  get locale(): Locale {
    return getLocale();
  },
  get dir(): "ltr" | "rtl" {
    return getTextDirection(getLocale());
  },
};
