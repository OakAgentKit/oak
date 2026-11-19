# QHooks reads and unsigned plans

This Node.js 22 example adds a public adapter for QHooks on Robinhood Chain (`4663`). It uses QHooks' keyless [MCP endpoint](https://qhooks.com/mcp) and the standard Oak MCP `account` read for the public wallet address. The included CLI defaults to offline fixtures and refuses live mode; it never opens a wallet, signs, sends a transaction, or installs anything.

```sh
node 04-qhooks/index.mjs
node --test 04-qhooks/*.test.mjs
```

Run these commands from `examples/`. Amounts are positive decimal **base-unit strings**, never floating-point token amounts.

| Adapter tool | QHooks tool | Result |
| --- | --- | --- |
| `qhooks_list_launches` | `list_launches` | Recent indexed launches; coverage and dates retained. |
| `qhooks_token_info` | `token_info` | Exact-address market data; source and stale flags retained. |
| `qhooks_quote` | `quote` | Token-based buy/sell quote. The QHooks fee-router adjustment is shown separately by prepare_trade. |
| `qhooks_qproof_check` | `qproof_check` | Stored QProof evidence. `not_checked`, missing/stale data and timestamps remain unchanged; no fresh scan is requested. |
| `qhooks_hooks_catalog` | `hooks_catalog` | Stored hook catalog, source dates and coverage. |
| `qhooks_prepare_trade` | `prepare_trade` | Ordered unsigned transactions for the public Oak wallet. |
| `qhooks_prepare_launch` | `prepare_launch` | A QHooks browser review link; no launch transaction is submitted. |

These are the example adapter's names, **not a claim that Oak 0.3.10 registers seven new native tools**. No catalog counts are changed. Public module exports are `QHOOKS_TOOLS`, `createQHooksClient`, and `createQHooksModule`; consumers can supply their existing standard Oak MCP client for the `account` callback. `index.mjs` demonstrates this wiring without private package files.

```js
import {createQHooksClient, createQHooksModule} from './qhooks.mjs';
const qhooks = createQHooksModule({
  client: createQHooksClient(),
  account: async () => { /* return the public {address} from Oak's account tool */ },
  // referrer: '0x…' // optional, configured public EVM address
});
const result = await qhooks.call('qhooks_prepare_trade', {
  token: '0x…', side: 'buy', amountIn: '1000000000000000'
});
```

Use real full contract addresses in application code. `referrer` maps unchanged to QHooks, in this order: explicit argument, module option, public Oak wallet. A supplied trader must match the public Oak account. No referrer reward, affiliate arrangement or earnings is promised.

## Local trade-plan validation

Before returning a trade preparation, the adapter checks RH `4663` on the plan and **every transaction**, and binds the trader to the public Oak account. It allows only the exact input token, the pinned QFeeRouter and Permit2 as destinations; the current direct-router route accepts only an optional exact-amount ERC-20 approval to QFeeRouter followed by its supported single-hop swap. Permit2 execution is not implemented and unknown selectors, extra operations and wallet-authorization fields are rejected.

The local decoder checks the pool manager, currencies and direction, requested raw amount, quote-derived minimum output and slippage, 100-bps fee, referrer, expiry, empty hook data and native value. ERC-20 operations must have zero native value; native-input swaps must carry exactly the input amount. QFeeRouter's `swap()` pays `msg.sender`: there is no separate trader/recipient argument in its ABI. The plan, quote and any transaction `from` must therefore match the actual Oak account.

The required `qhooks.trade-plan.v1` SHA-256 digest detects plan changes but is **not a server signature or a trusted price source**. Independently validated request and ABI constraints still apply even when a tampered response has a recomputed digest. Server responses without the new per-transaction `chainId` and integrity metadata fail closed; live trading preparation requires that QHooks server update. The offline example includes that exact metadata. Signing plans is future work.

The fixture tests include an unlimited approval plus a 5-ETH attacker transfer, changed chains/senders, wrong approval spender/amount, altered swap fields, expired plans and invalid native value. Nothing signs or executes during validation. Oak's own local simulation, spending limits and approval remain required before native execution can be enabled.

## Execution boundary

`prepare_*` returns `status: "prepared_only"` and `executionSupported: false`. Prepared for the signing wallet: the agent's own wallet or yours. QHooks has no custody and never holds keys. This adapter has no signer or transaction sender.

Oak's native TypeScript modules and hosted reader are private. Its local sender accepts pinned module destinations, calldata and reconstructed inputs; no public arbitrary-module registration API is documented. Native execution needs an Oak-maintained QHooks module with these guards. It must use the normal `oak_prepare` summary → explicit yes/no → `oak_execute` flow, re-simulate before signing, and retain finite approvals and spending limits. **Never pass returned bytes to generic `send`, rewrite them into an unrelated swap, or bypass those guards.** A launch link still requires the existing QHooks browser review and key flow; this example does not promise an Oak-native launch execution path.

If Oak rejects a destination or cannot validate the module, stop. A stored QProof verdict or successful buy simulation does not establish token safety or sellability. HTTP and MCP errors remain errors; `Retry-After` is exposed and no preparation or payment is retried automatically.

## Opt-in contract reads

[`recipe-package/`](recipe-package/) contains four `oak-recipe/v1` read recipes for QOtcEscrow/QAgreements fee configuration on RH. They are **as-is, not reviewed by Oak**. They call on-chain `view` methods; they cannot wrap HTTP QProof, discovery or unsigned plans. Contract addresses and runtime hashes were checked through public RPC at the block recorded in [contract evidence](CONTRACTS.md).

Package locally without lifecycle scripts or network:

```sh
npm_config_offline=true npm pack ./04-qhooks/recipe-package --ignore-scripts
# Owner opt-in, not executed by this example:
oak recipes add ./qhooks-oak-recipes-0.1.0.tgz
```

Imported names are `qhooks.escrow-fee-bps`, `qhooks.escrow-fee-recipient`, `qhooks.agreement-fee-bps`, and `qhooks.agreement-fee-recipient`. No transaction recipes, approvals or install scripts are included.

The module and fixtures target QHooks' seven named read/prepare tools captured from the current server source. They intentionally exclude feedback, paid x402 scans, submissions and all direct transaction execution. Oak-native registration and packed 0.3.10 bridge qualification remain maintainer acceptance work; this candidate does not claim those checks passed.

## Independent plan checks

Before a spot plan is returned, the adapter separately reads `token_info` and `quote` through the same configured public transport. It selects the listed launch pool (otherwise the first listed pool), binds the decoded currencies, hook, fee and tick spacing to that independent metadata, and computes the minimum from the independent raw quote, the original slippage and the router fee. Changing both the returned plan quote and its minimum, even with a recomputed digest, is refused. Missing or stale independent quote evidence stops preparation; there is no wallet call or automatic retry. This adds two bounded read calls per spot preparation.

The SHA-256 integrity value detects inconsistency; it is not a server signature or a price guarantee. Independent reads must come from the adapter's own transport, never model-supplied evidence or fields copied from the plan. Wallet review and signing remain outside the adapter.

This example remains `prepared_only`: Oak has no registered native QHooks executor here. It does not add OTC/agreement execution or bypass local wallet approval.
