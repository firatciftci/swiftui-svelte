<hstack class="items-center gap-2">
  <btn
    class="cursor-pointer p-2 text-neutral-800 opacity-80 transition-opacity hover:opacity-100 active:opacity-100 dark:text-neutral-50"
    onclick={() => {}}
  >
    <sfsymbol
      name="plus.diamond"
      size={20}
      weight="semibold"
      label="yeni sözcük öner"
    />
  </btn>
  <btn
    class="cursor-pointer p-2 text-neutral-800 opacity-80 transition-opacity hover:opacity-100 active:opacity-100 dark:text-neutral-50"
    onclick={() => {}}
  >
    <sfsymbol
      name="envelope"
      size={20}
      weight="semibold"
      label="iletişime geç"
    />
  </btn>
</hstack>
<vstack
  class="mt-2 gap-2 rounded-lg border-t border-neutral-300 pt-2 dark:border-neutral-700"
  css
  axis="vertical"
  container=""
>
  <txt
    boxsizing="border-box"
    width={160}
    border={{ width: 2, color: "orange" }}
  >
    Sized with its border inside
  </txt>
  <txt
    margin={{ leading: "auto", trailing: "auto" }}
    balanced
    class="text-sm text-neutral-600 dark:text-neutral-300"
  >
    Centered with margin, and balanced across its lines
  </txt>
  <txt selfalign="end" class="text-sm text-neutral-600 dark:text-neutral-300">
    Aligned to the end of the stack
  </txt>
  <txt class="text-sm text-neutral-600 dark:text-neutral-300">
    Borders take space, like padding
  </txt>
</vstack>
