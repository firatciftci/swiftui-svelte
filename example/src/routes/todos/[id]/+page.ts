import { error } from "swiftui-svelte/kit";
import type { PageLoadEvent } from "./$types";
import { todos } from "../../../todos.svelte";

export const load = ({ params }: PageLoadEvent) => {
  const id = Number(params.id);
  if (todos.every((todo) => todo.id !== id)) {
    error(404, "There's no to-do with that ID.");
  }
  return { id };
};
