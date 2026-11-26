import { error } from "swiftui-svelte/kit";

let runs = 0;

export const load = ({
  params,
  depends,
}: {
  params: { id: string };
  depends: (...keys: Array<string>) => void;
}): { id: number; runs: number } => {
  depends("app:items");
  runs += 1;
  const id = Number(params.id);
  if (![1, 2, 3].includes(id)) error(404, "No such item");
  return { id, runs };
};
