<script lang="ts">
  import { NavSplitView } from "swiftui-svelte/components";

  const { onclose }: { onclose: () => void } = $props();

  const mailboxes = [
    {
      id: "inbox",
      title: "Inbox",
      symbol: "tray",
      messages: [
        {
          id: 1,
          subject: "Lunch on Friday?",
          body: "There's a new place by the park. Want to try it at noon?",
        },
        {
          id: 2,
          subject: "Your order has shipped",
          body: "Your package is on its way and should arrive on Tuesday.",
        },
      ],
    },
    {
      id: "archive",
      title: "Archive",
      symbol: "archivebox",
      messages: [
        {
          id: 3,
          subject: "Trip photos",
          body: "Here are the photos from the lake. The sunset ones came out great.",
        },
      ],
    },
    {
      id: "drafts",
      title: "Drafts",
      symbol: "doc",
      messages: [
        {
          id: 4,
          subject: "Notes for the meeting",
          body: "Start with the release date, then go over the open bugs.",
        },
      ],
    },
  ];

  let mailboxId = $state<string | null>(null);
  let messageId = $state<number | null>(null);
  let column = $state<"sidebar" | "content" | "detail">("sidebar");
  let visibility = $state<"automatic" | "all" | "doubleColumn" | "detailOnly">(
    "all",
  );

  const mailbox = $derived(mailboxes.find((box) => box.id === mailboxId));
  const message = $derived(
    mailbox?.messages.find((item) => item.id === messageId),
  );
</script>

<NavSplitView
  testid="mail"
  variant="balanced"
  bind:visibility
  bind:compactcolumn={column}
>
  <screen title="Mailboxes" columnwidth={{ min: 200, ideal: 240, max: 320 }}>
    <list>
      {#each mailboxes as box (box.id)}
        <btn
          onclick={() => {
            mailboxId = box.id;
            messageId = null;
            column = "content";
          }}
        >
          <labelview title={box.title} symbol={box.symbol} />
        </btn>
      {/each}
    </list>
    <toolbar placement="cancellationAction">
      <btn onclick={onclose}>Done</btn>
    </toolbar>
  </screen>
  <screen title={mailbox?.title ?? ""}>
    {#if mailbox == null}
      <contentunavailableview
        title="No mailbox selected"
        symbol="tray"
        description="Pick a mailbox to see its messages."
      />
    {:else}
      <list>
        {#each mailbox.messages as item (item.id)}
          <btn
            onclick={() => {
              messageId = item.id;
              column = "detail";
            }}
          >
            {item.subject}
          </btn>
        {/each}
      </list>
    {/if}
  </screen>
  <screen title={message?.subject ?? ""} titledisplaymode="inline">
    {#if message == null}
      <contentunavailableview
        title="No message selected"
        symbol="envelope"
        description="Pick a message to read it here."
      />
      <txt testid="split-state" font="footnote" color="secondary"
        >{visibility} {column}</txt
      >
    {:else}
      <scrollview>
        <txt testid="message-body" padding>{message.body}</txt>
      </scrollview>
    {/if}
  </screen>
</NavSplitView>
