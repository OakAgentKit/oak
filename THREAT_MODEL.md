# Threat model

Oak's security documentation covers the shared custody and authority model. The sections below add the LayerBank and Pendle boundaries and limits.
Use these sections when describing the impact of a report:

- **Custody:** [Where your key lives](docs/security.md#2-where-your-key-lives-local-self-custody): the wallet is created and used on the user's machine; the hosted service never receives it.
- **Authority:** [Keys and authority matrix](docs/security.md#4-keys-and-authority-matrix): what each key can and cannot do, including the single owner key and the sign-only price signer.
- **Burner bounds:** [Burner 90-day armed sweep rule](docs/security.md#5-burner-90-day-armed-sweep-rule) and [exact on-chain burner checks](docs/security.md#6-exact-on-chain-burner-checks).
- **Contract invariants:** [docs/INVARIANTS.md](docs/INVARIANTS.md), with Foundry tests in [contracts/test](contracts/test/).
- **Transaction checks and limits:** [Before anything signs](README.md#before-anything-signs) lists the local checks, the confirmation step and what they do not prove.

Report a vulnerability privately as described in [SECURITY.md](SECURITY.md).

## Ecosystem assets and trust boundaries

Oak connects to **28 ecosystem projects** on Robinhood Chain (`4663`). `earn_options` is a read-only comparison helper and is excluded from that count. The ecosystem modules other than ERC-8004 are mainnet-only.

| Asset | What is at stake |
| --- | --- |
| LayerBank USDG deposits (`lRobUSDG`), Pendle principal tokens (PT) and ended-term payouts | Unauthorized signing, bad trade parameters, thin liquidity, third-party contract bugs or changes can cause loss or prevent an exit. |

LayerBank deposits and withdrawals call the pinned pool. Pendle trades call the pinned router. Oak pins addresses and function selectors, rather than contract code. Pendle's hosted API (`api-v2.pendle.finance`) supplies untrusted market lists and trade calldata and sees the requesting wallet address and trade amounts. For an ended term, Oak builds the cash-out call locally from chain reads; an optional quote request to Pendle includes the wallet address and PT amount, lasts at most 1.5 seconds and can add a notice without changing the transaction. `earn_options` signs nothing. Neither new module is registered on testnet.

## Threat H: Untrusted Pendle calls and limited LayerBank cash

- Oak decodes Pendle calldata using its own ABI fragments for exactly three functions: `swapExactTokenForPt`, `swapExactPtForToken` and `redeemPyToToken`. It refuses other selectors, a destination other than the pinned router, nonzero ETH value, a receiver other than your wallet, mismatched markets or tokens, external swap routers or swap data, and limit orders. Aggregator routing is off. Oak recomputes the minimum output from your slippage setting: defaults are 50 bps for USDG markets and 100 bps for stock-token markets, with caps of 100 and 200 bps. Quotes older than 30 seconds at signing are refused.
- Oak checks each market against Pendle's factory and checks the quoted amount against chain state. It refuses a trade if the chain read fails, the API amount differs too much from the chain estimate, or absolute price impact exceeds 3%. These checks bound the accepted call; they do not prove a fair market price. API free text is quoted as untrusted data. If the API is unavailable or fails validation, buys and sells are refused; no second calldata source is used.
- Ended terms use a locally built cash-out call, with minimum output 10 bps below the chain estimate by default and a 50 bps cap. The optional API comparison cannot change that call.
- LayerBank actions use only the pinned pool, and Pendle actions use only the pinned router. Approvals are for the exact amount of the action. LayerBank deposits check the reserve for pauses, freezes and supply-cap room. Withdrawals check cash on hand.

## Limits Oak cannot remove

- **Upgradeable contracts:** Pendle's router (`0x888888888889758F76e7103c6CbF23ABbF58F946`) is a proxy owned by a contract whose signers and threshold Oak has not verified. LayerBank's pool (`0x433e21dC2BF027910B1635653c2Eb630bC7dAD43`) and `lRobUSDG` are proxies too; Oak has not resolved the pool owner's or ACL admin's signers. Address and selector checks cannot verify new code behind an unchanged address.
- **Withdrawal cash:** LayerBank lends deposits out. Only the cash held by the pool at that moment is available for withdrawals. Oak refuses when no cash is available; if less than requested is available, it offers the smaller amount only if you agree. Oak cannot add cash, and LayerBank's own site has the same limit.
- **Early exits:** Selling Pendle PT before the end date uses the current market price and can pay less than you put in. Live terms are not promises from Oak.
- **Stock-token cash-outs:** An ended stock-token term pays the stock token itself, whose dollar value can change. It does not pay USDG. A swap to USDG is a separate step you confirm, and the issuer's transfer rules still apply.

## Before a deposit or term

Read the confirmation screen's end date, early-exit line and cash-on-hand line. Choose an amount that allows for a partial withdrawal or a sale at the current market price. Expect the stock token itself when cashing out an ended stock-token term.
