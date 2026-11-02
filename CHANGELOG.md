# Changelog

## 0.2.1 — release candidate (unpublished)

- Add the MCP Registry identity `io.github.OakAgentKit/oak` to the add-on manifest and prepare its registry descriptor.
- Accept private keys without a `0x` prefix during owner-terminal recovery; explain how to recover an account from a 12-word phrase without echoing it.
- Add the Claude Code plugin marketplace and editor install links. Install shortcuts remain pinned to published 0.2.0 until this candidate is published.
- License the install plugin files and the `oak-recipe/v1` recipe format/schema under MIT. The add-on and core implementation license remains “Free to use, no copying.”
- Support Node.js 22.12.0 or newer in the published package manifests. The 0.2.1 candidate passes isolated install, MCP startup and 3,809 add-on tests on Node 22.23.4, 24.22.2 and 25.9.0; workspace build tooling remains pinned to Node 22.

## 0.2.0 - 2026-11-02

- Publish core and add-on 0.2.0 and the live mainnet token, oracle, burner and subscription deployment records with receipt hashes.
- Publish the funded OakTeamVesting lock, its source and tests: 365 days linear from 2027-02-01, beneficiary launch wallet, no additional cliff.

- Include the identity and subscription lifecycle for paid actions, while keeping read tools available without a subscription. Hosted actions now use the verified launch deployment in paid mode; phase still controls available plans.
- Pin the OAK token, oracle, burner, subscription and ETH/USDG pool per chain. Refuse missing pins or discovery/configuration disagreements before signing.
- Verify short approval-census log pages against block receipts before recording coverage; pause actions when completeness cannot be established.
- Budget aggregator swap gas for forwarded execution and replay the ordered bundle at the final limits before signing. Refuse bundles that cannot fit the local or affordable gas ceiling.

## 0.1.9

- Flag token-level default approvals separately, so Oak does not mistake them for approvals you made or recommend revoking them.
- Show Orbio CREDIT remaining after a tool call without subtracting its charge twice.
- Explain that Orbio tool payloads belong in `args`; keep `arguments` as the outer `run_tool` wrapper.
- Internal cleanup, no behaviour change.

- Fix KyberSwap previews that rejected valid swaps because a pool emitted an anonymous log; keep rejecting malformed transfers involving your wallet.

- Expand the project tools and guided workflows, with a short everyday tool list and `find_tool` / `run_tool` access to the full catalog.
- Incorporate fixes from live tests with real funds across swaps, lending, deposits, liquidity, bridges and identity. These tests cover recorded journeys, not every tool or future execution.
- Default automatic signing to a 50 USD budget per local calendar day when the owner selects auto mode. Spending above the remaining budget, missing fresh USD values or unavailable usage records requires human approval; explicitly approved spending is not capped by this budget.
- Strengthen exact approval checks, delegate allowance discovery and cleanup, launch recipient checks, receipt minimums and confirmation binding. Reuse finalized approval discovery so ordinary swaps stay usable while older history catches up.
- Fix slow swap confirmations and quote expiry handling, preserve quoted minimum outputs and improve reference-price and fee guidance.
- Keep the reviewed aggregator swap through its approval: the swap you review is the swap that is sent. Fast and slow answers no longer waste approvals because of changed gas estimates or cached quote expiry; changed execution terms still need review.
- Retain journal entries for unconfigured chains while allowing other configured chains to proceed. Signing on the unconfigured chain stays paused until its RPC is configured.
- Make Orbio credit status a read without creating a credential. Explicit account authentication explains that its credential can spend activated CREDIT; status reuses the cached local credential and labels CREDIT correctly.
- Show Relay's provider-selected slippage and the minimum returned in its quote; Oak does not send a slippage parameter for that quote.
- Improve Relay funding setup, ERC-20 bridge flows and pending status; correct Orbio credit and gateway status and minimum-output checks.
- Restore Meridian buy and sell journeys, accept settlement acknowledgements, bind RFQ terms and preserve sale floors. External settlement still needs its own status check.
- Improve Beefy, HoodLock, Uniswap, NetNet, Longbow, Morpho, Priors, hood.ag and research workflows, error messages and agent playbooks.
- Clarify local wallet key protection and keep recovery words and private-key export in the owner's terminal.

## 0.1.2

- [Changed] The send tool is not offered in this version, and direct calls are refused.
- [Changed] Longbow deposits are enabled after fork verification of deposits, full withdrawals and zero leftover allowance. Meridian buys remain coming soon and are refused before signing.
- [Added] Startup instructions and project playbooks ship as MCP resources in the add-on.
- [Changed] Confirmation and signing guards are unchanged from 0.1.1. Discovery still lists 102 mainnet tools and 16 testnet tools.

## 0.1.1 (2026-10-30)

Oak now asks before signing an action by default. Review the MCP confirmation
form, or answer the terminal prompt for renewal and cancellation. The local wallet
checks what a transaction spends and who it calls, then simulates it again before
signing. Transaction results show whether they were submitted or mined and include
hashes; confirmations can take longer with the new 30-confirmation default.
Hosted access remains team-only.
Automatic first-start wallet creation already shipped in 0.1.0.

Technical changes:

- [Added] Default human confirmation through MCP forms before transaction and typed action signatures; decline, timeout and unavailable forms stop signing.
- [Security] Validate swap terms, module destinations, approval spenders and wallet outflows locally; refuse unlimited or incremental grants, unsupported permits and blanket operator approvals.
- [Security] Re-simulate exact transaction bytes after confirmation and refuse changed transfers or approvals before signing.
- [Changed] Owner-selected auto mode retains local checks; default-mode renewal can require human confirmation.
- [Changed] Use 30 canonical confirmations for transaction finality.
- [Added] Terminal y/N confirmation for `oak renew` and `oak cancel`; TTY-only selection of `confirm auto`; `confirm ask` restores prompts without requiring a TTY.
- [Security] Read post-state allowances, pin transaction callees, and bound fee/gas refresh before signing.
- [Changed] Confirmation authorization remains valid for 300 seconds.
- [Fixed] Resume identity registration after interruption without minting again.
- [Fixed] Priors and HEY integration behavior, small-swap rounding, and Velora fee-schema handling.
- [Fixed] Allow quoting when a reference price is unavailable; price-impact comparison remains unavailable in that case.
- [Changed] Lead action results with Submitted/Mined status and transaction hashes.
- [Changed] CLI discovery exposes 102 mainnet tools, including four local lifecycle tools (16 on testnet).
- [Added] Illustrated repository overview, plain-English introduction, docs index and launch-access guide.
- [Changed] Attribute the oracle tick conversion to its MIT-licensed Uniswap v4-core source and strengthen differential, boundary, monotonicity, mutation-control and exhaustive tests.

## 0.1.0 - 2026-10-29

- [Added] Released the local-custody Oak MCP, CLI, ERC-8004 identity lifecycle, subscription lifecycle, and 25 Robinhood Chain ecosystem modules.
- [Added] Published the Oak subscription, oracle, and burner contracts with Foundry tests, deployment scripts, ABIs, examples, and operator documentation.
- [Added] Added automatic local wallet creation, preview-before-signing, finite approval validation, payment journaling, public repository checks, and runnable Node.js examples.
- [Fixed] Required holder-plan renewals to retain the recorded post-burn OAK count before any USDG payment is collected.
