# 02 — Preview a swap and stop before signing

Goal: discover verified tokens, quote exact input, build unsigned approvals and
swap calldata with core's public API, and display the `preview` result for review.

Prerequisites: Node 22 and the [packed-package installation](../README.md).
Fixtures need no wallet. Optional live reads require a local mainnet wallet and
published service URL; see the parent README for authentication details.

From the installed examples directory:

```sh
npm run preview
node --test 02-preview-sign-swap/example.test.mjs
```

Defaults: USDG → WETH, `10000000` input base units (10 USDG), 50 bps slippage.
Optional exported variables: `OAK_FROM`, `OAK_TO`, `OAK_AMOUNT_IN`,
`OAK_SLIPPAGE_BPS`. Amounts must be decimal integer strings, never floats.
Use an address if token lookup is ambiguous.

Expected fixture output: verified token metadata, quote minimum output,
two unsigned transactions (exact 10000000-unit approval plus swap), and simulated
10 USDG out / 0.005 WETH in. Fixture tokens/prices are illustrative. Missing
calldata, expired quotes, mismatched terms and failed simulations stop the flow.
The example never fabricates route calldata or calls `swap` to obtain it.

An interactive terminal asks for `CONFIRM` **after** displaying the preview.
Enter/EOF or a noninteractive run stops; `CONFIRM` prints a manual-handoff message.
**Even confirmation does not sign or send.** To proceed, request a fresh quote
and preview in your configured wallet client and explicitly approve its swap
there. Quotes last 60 seconds, while same-block preview reuse is at most 12
seconds. The handoff intentionally carries no reusable signing authorization.

The preview excludes gas and cannot guarantee future execution or sellability.
Warnings, minimum output, token metadata and unsigned calldata remain visible.
