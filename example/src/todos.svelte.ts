export type Todo = { id: number; title: string; done: boolean };

let nextId = 3;

export const todos: Array<Todo> = $state([
  { id: 1, title: "Read the custom renderer docs", done: true },
  { id: 2, title: "Render Svelte with SwiftUI", done: false },
]);

export function addTodo(title: string) {
  todos.push({ id: nextId++, title, done: false });
}

export function removeTodo(id: number) {
  const index = todos.findIndex((todo) => todo.id === id);
  if (index !== -1) todos.splice(index, 1);
}
