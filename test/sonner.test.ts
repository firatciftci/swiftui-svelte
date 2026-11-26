import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { toast, useSonner } from "swiftui-svelte/sonner";

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  toast.dismiss();
  vi.runAllTimers();
  vi.useRealTimers();
});

describe("sonner", () => {
  it("creates typed toasts and returns their ids", () => {
    const id = toast.success("kopyalandı");
    const error = toast.error("hata");
    expect(toast.getActiveToasts().map((item) => item.id)).toEqual([error, id]);
    expect(toast.getActiveToasts()[1]).toMatchObject({
      type: "success",
      title: "kopyalandı",
    });
  });

  it("updates a live toast that reuses its id", () => {
    toast.loading("gönderiliyor", { id: "send" });
    toast.success("gönderildi", { id: "send" });
    const active = toast.getActiveToasts();
    expect(active).toHaveLength(1);
    expect(active[0]).toMatchObject({ id: "send", type: "success" });
  });

  it("replaces a dismissed toast that reuses its id", () => {
    toast.message("ilk", {
      id: "same",
      action: { label: "Geri al", onClick() {} },
    });
    toast.dismiss("same");
    toast.message("ikinci", { id: "same" });
    const active = toast.getActiveToasts();
    expect(active).toHaveLength(1);
    expect(active[0]).toMatchObject({ title: "ikinci" });
    expect(active[0]?.action).toBeUndefined();
  });

  it("drops a dismissed toast from the active list", () => {
    const id = toast("bitti");
    toast.dismiss(id);
    expect(toast.getActiveToasts()).toHaveLength(0);
  });

  it("dismisses every toast when no id is given", () => {
    toast("bir");
    toast("iki");
    toast.dismiss();
    expect(toast.getActiveToasts()).toHaveLength(0);
  });

  it("follows a promise from loading to success", async () => {
    const id = toast.promise(Promise.resolve(7), {
      loading: "yükleniyor",
      success: (value) => `tamam ${value}`,
      error: "olmadı",
    });
    expect(toast.getActiveToasts()[0]).toMatchObject({ id, type: "loading" });
    await vi.runAllTimersAsync();
    expect(toast.getActiveToasts()[0]).toMatchObject({
      id,
      type: "success",
      title: "tamam 7",
    });
  });

  it("dismisses a loading toast when the promise resolves without a success message", async () => {
    toast.promise(Promise.resolve(), { loading: "bekleyin" });
    await vi.runAllTimersAsync();
    expect(toast.getActiveToasts()).toHaveLength(0);
  });

  it("keeps the error message when the promise rejects", async () => {
    toast.promise(Promise.reject(new Error("ağ")), {
      loading: "bekleyin",
      error: (error) => (error instanceof Error ? error.message : "olmadı"),
    });
    await vi.runAllTimersAsync();
    expect(toast.getActiveToasts()[0]).toMatchObject({
      type: "error",
      title: "ağ",
    });
  });

  it("exposes the active toasts through useSonner", () => {
    toast("görünür");
    expect(useSonner().toasts.map((item) => item.title)).toEqual(["görünür"]);
  });
});
