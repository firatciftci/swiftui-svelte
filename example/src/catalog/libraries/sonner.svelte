<script lang="ts">
  import { toast, Toaster } from "swiftui-svelte/sonner";
  import CustomToast from "./parts/CustomToast.svelte";

  const delay = (milliseconds: number) =>
    new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
</script>

<zstack>
  <vstack spacing={12} padding>
    <btn variant="bordered" onclick={() => toast("Link copied")}> Message </btn>
    <btn variant="prominent" onclick={() => toast.success("Saved")}>
      Success
    </btn>
    <btn
      variant="bordered"
      onclick={() =>
        toast.error("Could not save", {
          description: "Check your connection and try again.",
        })}
    >
      Error
    </btn>
    <btn
      variant="bordered"
      onclick={() =>
        toast("Word deleted", {
          action: { label: "Undo", onClick: () => toast.info("Restored") },
        })}
    >
      Action
    </btn>
    <btn
      variant="bordered"
      onclick={() =>
        toast.promise(delay(1_500), {
          loading: "Sending",
          success: "Sent",
          error: "Failed",
        })}
    >
      Promise
    </btn>
    <btn
      variant="bordered"
      onclick={() =>
        toast.custom(CustomToast, {
          componentProps: { title: "Custom toast" },
        })}
    >
      Custom
    </btn>
    <btn variant="borderless" role="cancel" onclick={() => toast.dismiss()}>
      Dismiss all
    </btn>
  </vstack>
  <Toaster richColors closeButton />
</zstack>
