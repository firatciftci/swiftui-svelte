import { flushSync } from "svelte";

export type Row = { id: number; label: string };

class Rows {
  items = $state.raw(new Array<Row>());
}

export const rows = new Rows();

export function show(items: Array<Row>): void {
  flushSync(() => {
    rows.items = items;
  });
}
