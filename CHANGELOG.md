# Changelog

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
