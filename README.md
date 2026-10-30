> **Banner added at launch.**
> Oak Agent Kit: local wallet and pre-sign previews.
> The launch banner will appear here.
> No banner image is included in this snapshot.

# Oak Agent Kit

[![npm](https://img.shields.io/badge/npm-available_at_launch-E2AA5B?labelColor=062F27)](LICENSE-PACKAGES.md)
[![CI](https://img.shields.io/badge/CI-examples_%26_contracts-C3F56B?labelColor=062F27)](#contracts-deployments--pricing)
[![Chain](https://img.shields.io/badge/Robinhood_Chain-4663-E2AA5B?labelColor=062F27)](docs/robinhood-chain-projects.md)
[![License](https://img.shields.io/badge/License-MIT_·_Free--to--Use-C3F56B?labelColor=062F27)](LICENSE)

**One MCP for the whole chain.** Oak (`@oakagentkit/addon`, available at launch) gives your AI agent a local wallet, pre-sign `eth_simulateV1` previews, and **100 MCP tools** across **25 projects** on **Robinhood Chain** (`4663`, `0x1237`; **14 tools** on testnet `46630`).

## 60-Second Quickstart

Requires **Node.js 22 LTS** (`>=22.12.0 <23`); `@oakagentkit/addon` is **available at launch**:

```bash
npm install -g @oakagentkit/addon   # available at launch on npm
oak init                            # run in your own terminal, never via agent
oak setup                           # link or register ERC-8004 agent identity
oak subscribe --plan nohold         # launch curve: holder is closed
claude mcp add oak -- oak mcp
```

```json
{"mcpServers":{"oak":{"command":"oak","args":["mcp"]}}}
```

Prompt: *"Quote 10 USDG (`10000000`) to TSLA and show the preview before signing."* Client guides: [`docs/client-setup/`](docs/client-setup/).

## How Oak Works

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/arch-dark.svg" width="1200" height="460">
  <img src="assets/arch-light.svg" width="1200" height="460" alt="Signing flow: Agent to Oak MCP to Preview to Local Wallet to 25 Projects">
</picture>

1. **Local wallet (`~/.oak/wallet.enc`):** Created via `oak init` in your terminal. Recovery words and private keys never leave your computer; Oak cannot recover a lost key.
2. **Hosted service:** Serves token, price, position, and route reads, verifies ERC-8004 identities and subscriptions, builds unsigned transactions and previews, and signs 30-minute `$OAK` price notes. Never sees your key, signs, or sends transactions.
3. **Preview & local signing:** Action tools build exact approvals (never unlimited), run `preview` (reusing a same-block preview within 12s), and sign locally. Subscriptions auto-renew within 3 days of expiry while `oak mcp` runs using local signing and USDG.

## Pre-Sign Preview Demo

> **Demo video added at launch.** A pre-sign preview recording will appear here; this snapshot includes no video.

Every action simulates unsigned calldata via `eth_simulateV1` (`traceTransfers: true`), showing simulated transfer deltas before local signing. Quotes carry `minimumOutput` and warn above 2% price impact against fresh reference prices; simulation excludes gas and cannot prove external settlement or sellability.

## Open vs. Closed

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/boundary-dark.svg" width="1200" height="320">
  <img src="assets/boundary-light.svg" width="1200" height="320" alt="Trust boundary: MIT open repository versus free-to-use npm packages and hosted service">
</picture>

| Surface | Availability | License | Scope |
|---|---|---|---|
| `docs/`, `examples/` | Public in repo | [MIT](LICENSE) | Guides, 100-tool reference (14 testnet), and examples. Recipe packages are opt-in data (`as-is, not reviewed by Oak`); no recipe package ships in this snapshot. |
| `contracts/` | Public in repo | [MIT](LICENSE) | `OakSubscription.sol`, `OakOracle.sol`, `OakBurner.sol`, ABIs, Foundry tests (`forge test`). |
| `@oakagentkit/addon`, `@oakagentkit/core` | npm (available at launch) | [Free-to-Use, No Copying](LICENSE-PACKAGES.md) | Compiled CLI, local wallet, `oak mcp` bridge, and 25 connectors. Source is private. |
| Oak Hosted Service | Hosted (available at launch) | Proprietary (Private) | Token/route/position reads, identity/subscription checks, preview simulation, price-note signing. |

## Examples & 25 Projects

Runnable Node 22 packages in [`examples/`](examples/) (`node test-packed.mjs <core.tgz> <addon.tgz>` or `npm test`; offline fixtures by default):

- **[`examples/01-quickstart-mcp/`](examples/01-quickstart-mcp/)** — Connect an MCP client and list all 100 tool names and schemas (`npm run quickstart`, `node --test 01-quickstart-mcp/example.test.mjs`).
- **[`examples/02-preview-sign-swap/`](examples/02-preview-sign-swap/)** — Run `find_token` → `quote` → `preview` with exact approvals and stop before signing (`npm run preview`, `node --test 02-preview-sign-swap/example.test.mjs`).
- **[`examples/03-portfolio-agent/`](examples/03-portfolio-agent/)** — Read `balances` and `positions` across the 25 modules (`npm run portfolio`, `node --test 03-portfolio-agent/example.test.mjs`).

| Category | Robinhood Chain (`4663`) Projects |
|---|---|
| Swap & Trade | KyberSwap, Velora, Pons, pools.trade, Clanker, Hookr, TickerSpring, Uniswap liquidity (`v3`/`v4`) |
| Vaults & Rewards | Steakhouse, Spark, NetNet, Longbow, Grove, Beefy, Merkl (Powered by Merkl — https://app.merkl.xyz) |
| Borrow & Lend | Morpho Blue, Priors |
| Move Money | Relay, Orbio |
| Markets & Data | Meridian, Lighter, HeyResearch (with HeyResearch attribution) |
| Identity & Tools | ERC-8004, hood.ag, HoodLock |

Pons includes launch discovery (`pons_launch_options`), launch (`pons_launch`), and creator controls (`pons_transfer_creator_fee_recipient`, `pons_set_buyback`) plus curve/graduated trading, graduation, and claims. Catalogs: [`docs/robinhood-chain-projects.md`](docs/robinhood-chain-projects.md) · [`docs/mcp-tools-reference.md`](docs/mcp-tools-reference.md).

## Contracts, Deployments & Pricing

Run `cd contracts && forge test --offline` after installing the pinned contract dependencies and Solidity 0.8.26. Read the [independent review summaries](docs/reviews.md); no audit PDFs ship in this snapshot. `$OAK`, `OakSubscription`, `OakOracle`, and `OakBurner` addresses on `4663` and `46630` are **published at launch** in [`contracts/deployments/4663.json`](contracts/deployments/4663.json) and [`contracts/deployments/46630.json`](contracts/deployments/46630.json) (dormant `OAK` `0x38fE199550E677Fa9caC196495460dfF97BCe28F` is unrelated; `4663` USDG `0x5fc5360d0400a0fd4f2af552add042d716f1d168`, `46630` USDG `0x7E955252E15c84f5768B83c41a71F9eba181802F`, ETH/USDG pool `0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca`, ERC-8004 `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`).

- **Pricing (0% trade fee, no per-call fees):** 30-day USDG cycle (90-day prepay cap; `oak cancel` forfeits remaining days), splitting **25% to `OakBurner`** and **75% to the single-owner treasury wallet**.
- **Holder plan (9 USDG / 30d):** Hold entry-price count `N` of `$OAK`; a one-time sign-up burn burns 5% (`ceil(N * 5 / 100)`) and tracks `N - burn` as `signupOakCount` (e.g., hold 20,000, 1,000 burns, 19,000 tracked). Renewals burn nothing and need no note. Holding `$OAK` buys access and nothing else.
- **No-hold plan (9 USDG + 1/6 entry price / 30d):** **12.333333 USDG** at the $20 floor, re-priced each renewal.
- **Entry curve (`totalSupply()` × `$OAK` USD price; USDG = $1):** <$100k: $20 ($12.33 no-hold); $100k–$500k: $20→$75 ($12.33→$21.50); $500k–$1M: $75→$100 ($21.50→$25.67); $1M–$10M: $100→$300 ($25.67→$59); >$10M: $300 ($59).
- **Phases & 50% guard:** `curve` (`phase != 2`): only no-hold open at `12.333333 USDG`, holder closed. `warmup` (<30m history): both wait. `ready` (>=30m): holder open; 30-minute signed `$OAK` price notes (5-minute life) + on-chain ETH/USDG 30-minute average, guarded within **50% of live pool price**. These are service phases: the oracle itself becomes ready on graduation; the service waits for 30 minutes of history before issuing notes. Contract checks are documented in [security](docs/security.md).

## Security & Community

Treasury and contract admin is single-owner wallet `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`. One owner key can spend treasury funds, redirect future subscription payments, replace the price signer, and retire subscriptions (no second-signature requirement; cannot spend user balances).

Oak is not affiliated with Robinhood, shows a region notice by default, adds no safety checks or spending caps, and never promises returns.

[`docs/security.md`](docs/security.md) · [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) · [`LICENSE`](LICENSE) · [`LICENSE-PACKAGES.md`](LICENSE-PACKAGES.md) · [@OakAgentKit](https://x.com/OakAgentKit)

Run `oak init --recover` in your own terminal to restore your 24-word backup on a new computer. To replace an existing wallet, use `oak init --recover --replace`; Oak preserves an encrypted backup and asks you to confirm the recovered address. Never enter recovery words in an agent chat, arguments, environment variables or MCP tools.

For stdio MCP, Oak needs an accessible persistent OS keychain (Linux: Secret Service in the same unlocked user/D-Bus session as the MCP client). A passphrase-only wallet currently supports interactive CLI commands in your own terminal; it cannot start `oak mcp` through a pipe. Do not send the passphrase through MCP or store it in argv/environment variables. To enable MCP for an existing fallback wallet, first configure a persistent keychain, then restore with `oak init --recover --replace` yourself in your terminal and confirm the address. Keep the old encrypted backup and recovery words offline.

Mainnet uses `https://api.oakagentkit.org` by default. Override it with `oak config set OAK_SERVER_URL <https-url>` or `OAK_SERVER_URL`; testnet requires an explicit matching service URL. Configure the published deployment addresses and your RPC before starting MCP.

Headless setup: [persistent keychain guidance](docs/headless-wallet.md). Deployment JSON files are launch placeholders, not usable configuration.
