import type { ComponentProps } from "svelte";
import type Toaster from "./Toaster.svelte";
import type { ToastT } from "./types.ts";
import { toastStore } from "./state.svelte.ts";

export type ToasterProps = ComponentProps<typeof Toaster>;

export const toast = Object.assign(
  (title: string, data?: Parameters<typeof toastStore.message>[1]) =>
    toastStore.message(title, data),
  {
    success: toastStore.success,
    info: toastStore.info,
    warning: toastStore.warning,
    error: toastStore.error,
    loading: toastStore.loading,
    custom: toastStore.custom,
    message: toastStore.message,
    promise: toastStore.promise,
    dismiss: toastStore.dismiss,
    getActiveToasts: (): Array<ToastT> => toastStore.active,
  },
);

export function useSonner(): { readonly toasts: Array<ToastT> } {
  return {
    get toasts() {
      return toastStore.active;
    },
  };
}

export { default as Toaster } from "./Toaster.svelte";

export type {
  ExternalToast,
  Position,
  PromiseData,
  ToastAction,
  ToastComponent,
  ToastID,
  ToastT,
  ToastType,
} from "./types.ts";
