import { VERSION } from "svelte/compiler";

const keyedEach =
  /[/\\]svelte[/\\]src[/\\]internal[/\\]client[/\\]dom[/\\]blocks[/\\]each\.js$/;

const linearMarker = "(seen ??= new Map()).set(current, stashed.length)";

const linearReverse: Array<readonly [string, string]> = [
  [
    `					for (j = 0; j < stashed.length; j += 1) {
						seen.delete(stashed[j]);
					}

					link(state, a.prev, b.next);
					link(state, prev, a);
					link(state, b, start);

					current = start;
					prev = b;
					i -= 1;

					matched = [];
					stashed = [];
`,
    `					link(state, a.prev, b.next);
					link(state, prev, a);
					link(state, b, start);

					var k = seen.get(effect);

					if (stashed[k] === effect) {
						for (j = k; j < stashed.length; j += 1) {
							seen.delete(stashed[j]);
						}

						stashed.length = k;
						matched = [effect];
						prev = effect;
						current = skip_to_branch(effect.next);
					} else {
						for (j = 0; j < stashed.length; j += 1) {
							seen.delete(stashed[j]);
						}

						current = start;
						prev = b;
						i -= 1;

						matched = [];
						stashed = [];
					}
`,
  ],
  ["(seen ??= new Set()).add(current);", `${linearMarker};`],
  ["for (effect of seen) {", "for (effect of seen.keys()) {"],
];

export function fixSvelte(
  code: string,
  id: string,
): { code: string; map: null } | null {
  if (!keyedEach.test(id.split("?", 1)[0] ?? "") || code.includes(linearMarker))
    return null;
  let fixed = code;
  for (const [before, after] of linearReverse) {
    const index = fixed.indexOf(before);
    if (index === -1 || fixed.includes(before, index + 1)) {
      throw new Error(
        `swiftui(): swiftui-svelte patches Svelte's keyed each block so that reversing a long list doesn't slow down, but Svelte ${VERSION} changed that code and the patch no longer applies. Install a Svelte version that this version of swiftui-svelte supports, or update swiftui-svelte.`,
      );
    }
    fixed = fixed.slice(0, index) + after + fixed.slice(index + before.length);
  }
  return { code: fixed, map: null };
}
