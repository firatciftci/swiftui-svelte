export type Row = { id: number; label: string };

export const table = $state({ rows: new Array<Row>() });

const ids = { next: 1 };

export function create(count: number): void {
  const rows = new Array<Row>();
  for (let index = 0; index < count; index++) {
    rows.push({ id: ids.next, label: `Row ${ids.next}` });
    ids.next += 1;
  }
  table.rows = rows;
}

export function update(): void {
  for (const [index, row] of table.rows.entries()) {
    if (index % 10 === 0) row.label += " !";
  }
}

export function swap(): void {
  const { rows } = table;
  if (rows.length < 3) return;
  const second = rows[1];
  const last = rows.at(-2);
  if (second == null || last == null) return;
  rows[1] = last;
  rows[rows.length - 2] = second;
}

export function reverse(): void {
  table.rows.reverse();
}

export function clear(): void {
  table.rows = [];
}
