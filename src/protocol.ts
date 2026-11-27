export const protocol = 3;

export const opcodes = {
  root: 0,
  insert: 1,
  move: 2,
  remove: 3,
  attr: 4,
  unattr: 5,
  text: 6,
  name: 7,
} as const;
