# Security policy

## Supported versions

Security fixes go into the latest release. Until 1.0, that means the latest `0.x` version.

## Reporting a vulnerability

Do not open a public issue for a security problem. Report it privately through [GitHub's private vulnerability reporting](https://github.com/firatciftci/swiftui-svelte/security/advisories/new) instead.

Include what you found, the versions affected, and the steps or code to reproduce it. You'll get a reply within a week. Once the problem is confirmed, I will work on a fix with you, publish a release, and credit you in the advisory unless you would rather stay anonymous.

## Scope

`SvelteView` runs whatever JavaScript bundle you give it, with access to the network through `fetch` and to the app's storage through `localStorage`. Treat that bundle like the rest of your app's code: ship it inside the app, and don't load it from a server you don't control. A problem that needs an attacker to supply the bundle is out of scope, but a way for a bundle to reach more than `fetch`, `localStorage`, timers, and the console is a vulnerability, so please report it.

If the problem is in Svelte itself rather than in this package, report it to [Svelte](https://github.com/sveltejs/svelte/security) directly.
