# 02 — Prepare a swap, read the summary, and answer yes or no

Goal: discover verified tokens, quote exact input, check unsigned approvals and
swap calldata with core's public API, then call `oak_prepare` for a simulated
action. Read its plain summary, answer yes or no, and call `oak_execute` with
that exact `actionId` only after yes. This is the 0.3.0 approval flow.

Prerequisites: Node 22 and the [packed-package installation](../README.md).
Fixtures need no wallet. Optional live reads require a local mainnet wallet and
published service URL; see the parent README for authentication details. The
live client retains a disabled sender, so it cannot prepare or execute actions.

From the installed examples directory:

```sh
npm run preview
node --test 02-preview-sign-swap/example.test.mjs
```

Defaults: USDG → WETH, `10000000` input base units (10 USDG), 50 bps slippage.
Optional exported variables: `OAK_FROM`, `OAK_TO`, `OAK_AMOUNT_IN`,
`OAK_SLIPPAGE_BPS`. Amounts must be decimal integer strings, never floats.
Use an address if token lookup is ambiguous.

Expected fixture output: verified token metadata, quote minimum output, then a
plain summary of the action, wallet outflow, minimum received, fees, exact token
approval and warnings, followed by `actionId` and UTC expiry. The prepared swap
has two unsigned transactions (exact 10000000-unit approval plus swap).
Fixture tokens/prices are illustrative. Both KyberSwap and Velora fixtures run
through the real packed bridge. Missing calldata, expired quotes, mismatched
terms and failed simulations stop before asking for yes or reaching the sender.
The example never fabricates route calldata.

An interactive terminal asks for `yes` or `no` **after** displaying the exact
prepared summary. Enter/EOF or a noninteractive run stops. Only `yes` maps to the
explicit boolean approval used by the code; other answers never call execute.
After yes, the example calls `oak_execute {actionId}` once. It checks quote and
action expiry again first; expiry requires a fresh summary and a new answer.
There is no automatic execution retry or replacement of the approved action.

**The fixture sender never signs or broadcasts**, including after yes. It
gives back `status: not_submitted` and an empty hash list. The default and live
clients disable transaction and typed-data signing. Real wallet integration
must supply Oak's production sender, which re-simulates, checks local guards and
the optional daily spending limit, then signs locally after the person's yes.
The mock sender demonstrates call ordering, not those production signing checks.

The existing directory and `npm run preview` command remain stable. Its title
and behavior now teach preparation and chat approval instead of manual handoff.

The preview excludes gas and cannot guarantee future execution or sellability.
Warnings, minimum output, token metadata and unsigned calldata remain visible.
