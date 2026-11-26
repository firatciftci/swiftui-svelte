import { redirect } from "swiftui-svelte/kit";

export function load(): never {
  redirect(302, "/");
}
