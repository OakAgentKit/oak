# 03 — Read a portfolio across projects

Goal: make only `balances` and `positions` calls, preserve each token's address,
symbol, decimals, chain ID and base-unit amount, and display human amounts using
integer arithmetic. Positions retain their project/module and any error rows.
Oak 0.3.5's MCP `structuredContent` exposes balances under `items`; the example
also accepts the older array text form. Setup next steps and funding summaries
remain visible when the balance response includes them.

Prerequisites: Node 22 and the [packed-package installation](../README.md).
Fixtures need no wallet, RPC or funds. Optional live reads require a local
mainnet wallet and published service URL; no ERC-8004 identity is required for
these reads. Oak is free to use. Project coverage depends on the installed release.
Hosted `positions` cannot read Gloam notes because Gloam has no positions reader; use local `gloam_status` for those notes.

From the installed examples directory:

```sh
npm run portfolio
node --test 03-portfolio-agent/example.test.mjs
```

Expected fixture output: 25 USDG (`25000000` base units), positions labelled
`steakhouse`, `morpho` and `uniswap`, and an empty warnings array. The tests also
inject an unavailable project and verify its warning survives. Coverage fields
`incomplete`, `notIndexed` and per-program status remain visible even when the
reader supplies no error position row. Missing coverage is never counted as a
successful empty portfolio. Live positions
and module availability will differ; this is an inventory, not a valuation or
an investment recommendation. No model API, deposits, swaps or rebalancing run.

This example stays read-only. To act on a portfolio, use the separate
[swap approval example](../02-preview-sign-swap/): prepare the proposed action,
read its plain summary, ask the person for yes or no, and only after yes call
`oak_execute` with the exact prepared `actionId`. Reading a portfolio does not
give permission to rebalance it.
