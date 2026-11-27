import { parse } from "devalue";
import { router, showError } from "./client.svelte.ts";
import { goto, invalidateAll } from "./navigation.ts";

type ActionData = Record<string, unknown> | undefined;

export type ActionResult<
  Success extends ActionData = ActionData,
  Failure extends ActionData = ActionData,
> =
  | { type: "success"; status: number; data?: Success }
  | { type: "failure"; status: number; data?: Failure }
  | { type: "redirect"; status: number; location: string }
  | { type: "error"; status?: number; error: unknown };

export type SubmitFunction<
  Success extends ActionData = ActionData,
  Failure extends ActionData = ActionData,
> = (input: {
  action: URL;
  formData: FormData;
  formElement: HTMLFormElement;
  controller: AbortController;
  submitter: HTMLElement | null;
  cancel: () => void;
}) =>
  | Promise<void | AfterSubmit<Success, Failure>>
  | void
  | AfterSubmit<Success, Failure>;

type AfterSubmit<
  Success extends ActionData,
  Failure extends ActionData,
> = (options: {
  formData: FormData;
  formElement: HTMLFormElement;
  action: URL;
  result: ActionResult<Success, Failure>;
  update: (options?: {
    reset?: boolean;
    invalidateAll?: boolean;
  }) => Promise<void>;
}) => Promise<void> | void;

export function deserialize<
  Success extends ActionData = ActionData,
  Failure extends ActionData = ActionData,
>(result: string): ActionResult<Success, Failure> {
  const parsed: unknown = JSON.parse(result);
  if (
    typeof parsed === "object" &&
    parsed != null &&
    "data" in parsed &&
    typeof parsed.data === "string"
  ) {
    parsed.data = parse(parsed.data);
  }
  return parsed as ActionResult<Success, Failure>;
}

export async function applyAction<
  Success extends ActionData = ActionData,
  Failure extends ActionData = ActionData,
>(result: ActionResult<Success, Failure>): Promise<void> {
  if (result.type === "redirect") {
    await goto(result.location);
    await invalidateAll();
    return;
  }
  if (result.type === "error") {
    showError(result.status ?? 500, messageOf(result.error));
    return;
  }
  const top = router.top;
  if (top == null) return;
  top.form = result.data ?? null;
  top.view = { ...top.view, status: result.status };
}

function messageOf(error: unknown): string {
  if (
    typeof error === "object" &&
    error != null &&
    "message" in error &&
    typeof error.message === "string"
  ) {
    return error.message;
  }
  return "Internal Error";
}

export function enhance<
  Success extends ActionData = ActionData,
  Failure extends ActionData = ActionData,
>(
  _form: HTMLFormElement,
  _submit?: SubmitFunction<Success, Failure>,
): { destroy: () => void } {
  throw new Error(
    "enhance() needs a <form> element, and a swiftui-svelte app doesn't have one. Send the form data with fetch, or with superForm's validateForm() and your own request.",
  );
}
