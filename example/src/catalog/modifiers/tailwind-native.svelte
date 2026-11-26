<vstack
  class="gap-3 rounded-xl corner-squircle bg-white p-4 dark:bg-neutral-900"
>
  <txt class="text-neutral-800 dark:text-neutral-50">Native variants</txt>
  <txt class="ios:text-blue-600 android:text-green-600 web:text-red-600">
    Blue on iOS, green on Android
  </txt>
  <txt
    class="contrast-more:font-bold portrait:text-neutral-700 landscape:text-neutral-500"
  >
    Bold with Increase Contrast
  </txt>
  <txt class="label-color">Label color from platformColor</txt>
  <hstack class="items-center gap-2">
    <btn
      class="cursor-pointer rounded-full bg-brand-500 p-2 text-white elevation-md ripple-brand-500"
      onclick={() => {}}
    >
      <sfsymbol name="star.fill" size={16} label="favorite" />
    </btn>
  </hstack>
  <vstack class="hairline rounded-lg p-3">
    <txt class="text-sm text-neutral-600 dark:text-neutral-300"
      >Hairline border</txt
    >
  </vstack>
</vstack>
