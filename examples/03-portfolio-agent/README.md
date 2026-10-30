# 03 — Read a portfolio across projects

Goal: make only `balances` and `positions` calls, preserve each token's address,
symbol, decimals, chain ID and base-unit amount, and display human amounts using
integer arithmetic. Positions retain their project/module and any error rows.

Prerequisites: Node 22 and the [packed-package installation](../README.md).
Fixtures need no wallet, RPC or funds. Optional live reads require a local
mainnet wallet and published service URL; no ERC-8004 identity/subscription is
required. Mainnet's configured readers cover the 25 ecosystem modules.

From the installed examples directory:

```sh
npm run portfolio
node --test 03-portfolio-agent/example.test.mjs
```

Expected fixture output: 25 USDG (`25000000` base units), positions labelled
`steakhouse`, `morpho` and `uniswap`, and an empty warnings array. The tests also
inject an unavailable project and verify its warning survives. Live positions
and module availability will differ; this is an inventory, not a valuation or
an investment recommendation. No model API, deposits, swaps or rebalancing run.
