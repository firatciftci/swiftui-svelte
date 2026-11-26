import type { Component } from "svelte";

export type ToastID = number | string;

export type ToastType =
  | "default"
  | "success"
  | "error"
  | "info"
  | "warning"
  | "loading";

export type Position =
  | "top-left"
  | "top-right"
  | "bottom-left"
  | "bottom-right"
  | "top-center"
  | "bottom-center";

export type ToastAction = { label: string; onClick: () => void };

export type CustomToastProps = { closeToast: () => void };

export type ToastComponent = Component<CustomToastProps>;

export type ExternalToast = {
  id?: ToastID;
  description?: string;
  duration?: number;
  action?: ToastAction;
  cancel?: ToastAction;
  closeButton?: boolean;
  dismissible?: boolean;
  richColors?: boolean;
  toasterId?: string;
  onDismiss?: (toast: ToastT) => void;
  onAutoClose?: (toast: ToastT) => void;
};

export type ToastT = ExternalToast & {
  id: ToastID;
  type: ToastType;
  title?: string;
  component?: ToastComponent;
  componentProps?: object;
  dismiss: boolean;
};

export type PromiseData<Data = unknown> = ExternalToast & {
  loading?: string;
  success?: string | ((data: Data) => string);
  error?: string | ((error: unknown) => string);
  finally?: () => void | Promise<void>;
};
