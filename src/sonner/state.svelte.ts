import type { Component } from "svelte";
import type {
  CustomToastProps,
  ExternalToast,
  PromiseData,
  ToastComponent,
  ToastID,
  ToastT,
  ToastType,
} from "./types.ts";

const EXIT_DURATION_MS = 300;

type CreateData = ExternalToast & {
  title?: string;
  type?: ToastType;
  component?: ToastComponent;
  componentProps?: object;
};

class ToastStore {
  #counter = 0;
  toasts: Array<ToastT> = $state([]);

  create = (data: CreateData): ToastID => {
    const id = data.id ?? (this.#counter += 1);
    const type = data.type ?? "default";
    const existing = this.toasts.find((toast) => toast.id === id);
    if (existing != null && !existing.dismiss) {
      this.toasts = this.toasts.map((toast) =>
        toast.id === id
          ? { ...toast, ...data, id, type, dismiss: false }
          : toast,
      );
    } else {
      this.toasts = [
        { ...data, id, type, dismiss: false },
        ...this.toasts.filter((toast) => toast.id !== id),
      ];
    }
    return id;
  };

  dismiss = (id?: ToastID): ToastID | undefined => {
    if (id === undefined) {
      for (const toast of this.toasts) this.#dismiss(toast);
      return undefined;
    }
    const toast = this.toasts.find((candidate) => candidate.id === id);
    if (toast != null) this.#dismiss(toast);
    return id;
  };

  remove = (id: ToastID): void => {
    this.toasts = this.toasts.filter(
      (toast) => !(toast.id === id && toast.dismiss),
    );
  };

  message = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "default", title });

  success = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "success", title });

  error = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "error", title });

  info = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "info", title });

  warning = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "warning", title });

  loading = (title: string, data?: ExternalToast): ToastID =>
    this.create({ ...data, type: "loading", title });

  custom = <Props extends object>(
    component: Component<Props & CustomToastProps>,
    data?: ExternalToast & { componentProps?: Props },
  ): ToastID =>
    this.create({
      ...data,
      type: "default",
      component: component as ToastComponent,
    });

  promise = <Data>(
    promise: Promise<Data> | (() => Promise<Data>),
    data?: PromiseData<Data>,
  ): ToastID | undefined => {
    if (data == null) return undefined;
    let id: ToastID | undefined;
    if (data.loading !== undefined) {
      id = this.create({ ...data, type: "loading", title: data.loading });
    }
    const pending = promise instanceof Promise ? promise : promise();
    void this.#settle(pending, data, id);
    return id;
  };

  async #settle<Data>(
    pending: Promise<Data>,
    data: PromiseData<Data>,
    id: ToastID | undefined,
  ): Promise<void> {
    let shouldDismiss = id !== undefined;
    try {
      const response = await pending;
      if (data.success !== undefined) {
        shouldDismiss = false;
        const title =
          typeof data.success === "function"
            ? data.success(response)
            : data.success;
        this.create({ id, type: "success", title });
      }
    } catch (error: unknown) {
      if (data.error !== undefined) {
        shouldDismiss = false;
        const title =
          typeof data.error === "function" ? data.error(error) : data.error;
        this.create({ id, type: "error", title });
      }
    } finally {
      if (shouldDismiss && id !== undefined) this.dismiss(id);
      await data.finally?.();
    }
  }

  #dismiss(toast: ToastT): void {
    if (toast.dismiss) return;
    this.toasts = this.toasts.map((candidate) =>
      candidate.id === toast.id ? { ...candidate, dismiss: true } : candidate,
    );
    toast.onDismiss?.(toast);
    setTimeout(() => this.remove(toast.id), EXIT_DURATION_MS);
  }

  get active(): Array<ToastT> {
    return this.toasts.filter((toast) => !toast.dismiss);
  }
}

export const toastStore = new ToastStore();
