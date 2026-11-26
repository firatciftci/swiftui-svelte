import { error } from "swiftui-svelte/kit";

export function load(): never {
  error(404, "Nothing here");
}
