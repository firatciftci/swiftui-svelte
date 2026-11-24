export type Todo = { id: number; title: string; done: boolean };

const storageKey = "todos";

function isTodo(value: unknown): value is Todo {
  if (typeof value !== "object" || value == null) return false;
  const todo = value as Record<string, unknown>;
  return (
    typeof todo.id === "number" &&
    typeof todo.title === "string" &&
    typeof todo.done === "boolean"
  );
}

function load(): Array<Todo> {
  const saved = localStorage.getItem(storageKey);
  if (saved != null) {
    try {
      const parsed: unknown = JSON.parse(saved);
      if (Array.isArray(parsed) && parsed.every(isTodo)) return parsed;
    } catch {}
  }
  return [
    { id: 1, title: "Read the custom renderer docs", done: true },
    { id: 2, title: "Render Svelte with SwiftUI", done: false },
  ];
}

export const todos: Array<Todo> = $state(load());

let nextId = Math.max(0, ...todos.map((todo) => todo.id)) + 1;

$effect.root(() => {
  $effect(() => {
    localStorage.setItem(storageKey, JSON.stringify(todos));
  });
});

export function addTodo(title: string) {
  todos.push({ id: nextId++, title, done: false });
}

export function removeTodo(id: number) {
  const index = todos.findIndex((todo) => todo.id === id);
  if (index !== -1) todos.splice(index, 1);
}
