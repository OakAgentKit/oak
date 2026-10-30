> **Banner added at launch.**
> Oak Agent Kit: local wallet and pre-sign previews.
> The launch banner will appear here.
> No banner image is included in this snapshot.

# Oak Agent Kit

[![npm](https://img.shields.io/badge/npm-available_at_launch-E2AA5B?labelColor=062F27)](LICENSE-PACKAGES.md)
[![CI](https://img.shields.io/badge/CI-examples_%26_contracts-C3F56B?labelColor=062F27)](#contracts-deployments--pricing)
[![Chain](https://img.shields.io/badge/Robinhood_Chain-4663-E2AA5B?labelColor=062F27)](docs/robinhood-chain-projects.md)
[![License](https://img.shields.io/badge/License-MIT_·_Free--to--Use-C3F56B?labelColor=062F27)](LICENSE)

**One MCP for the whole chain.** Oak (`@oakagentkit/addon`, available at launch) gives your AI agent a local wallet, pre-sign `eth_simulateV1` previews, and **102 MCP tools** across **25 projects** on **Robinhood Chain** (`4663`, `0x1237`; **16 tools** on testnet `46630`).

## 60-Second Quickstart

Requires **Node.js 22 LTS** (`>=22.12.0 <23`); `@oakagentkit/addon` is **available at launch**:

```bash
npm install -g @oakagentkit/addon   # available at launch on npm
oak address                         # auto-create; show the public funding address
# Ask your agent to re-check balances after you fund ETH and USDG.
# Authorize oak_setup and approve a plan with oak_subscribe in MCP.
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

1. **Local wallet (`~/.oak/wallet.enc`):** Created automatically on first run, with OS keychain or owner-only file storage and no prompts. Recovery words and private keys never leave your computer; Oak cannot recover a lost key.
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
| `docs/`, `examples/` | Public in repo | [MIT](LICENSE) | Guides and tool reference (102 mainnet, 16 testnet), and examples. Recipe packages are opt-in data (`as-is, not reviewed by Oak`); no recipe package ships in this snapshot. |
| `contracts/` | Public in repo | [MIT](LICENSE) | `OakSubscription.sol`, `OakOracle.sol`, `OakBurner.sol`, ABIs, Foundry tests (`forge test`). |
| `@oakagentkit/addon`, `@oakagentkit/core` | npm (available at launch) | [Free-to-Use, No Copying](LICENSE-PACKAGES.md) | Compiled CLI, local wallet, `oak mcp` bridge, and 25 connectors. Source is private. |
| Oak Hosted Service | Hosted (available at launch) | Proprietary (Private) | Token/route/position reads, identity/subscription checks, preview simulation, price-note signing. |

## Examples & 25 Projects

Runnable Node 22 packages in [`examples/`](examples/) (`node test-packed.mjs <core.tgz> <addon.tgz>` or `npm test`; offline fixtures by default):

- **[`examples/01-quickstart-mcp/`](examples/01-quickstart-mcp/)** — Connect an MCP client and list tool names and schemas (`npm run quickstart`, `node --test 01-quickstart-mcp/example.test.mjs`).
- **[`examples/02-preview-sign-swap/`](examples/02-preview-sign-swap/)** — Run `find_token` → `quote` → `preview` with exact approvals and stop before signing (`npm run preview`, `node --test 02-preview-sign-swap/example.test.mjs`).
- **[`examples/03-portfolio-agent/`](examples/03-portfolio-agent/)** — Read `balances` and `positions` across the 25 modules (`npm run portfolio`, `node --test 03-portfolio-agent/example.test.mjs`).

| Category | Robinhood Chain (`4663`) Projects |
|---|---|
| Swap & Trade | KyberSwap, Velora, Pons, pools.trade, Clanker, Hookr, TickerSpring, Uniswap liquidity (`v3`/`v4`) |
| Vaults & Rewards | Steakhouse, Spark, NetNet, Longbow, Grove, Beefy, Merkl (Powered by Merkl — https://app.merkl.xyz) |
| Borrow & Lend | Morpho Blue, Priors |
| Move Money | Relay |
| Markets & Data | Meridian, Lighter, HeyResearch (with HeyResearch attribution) |
| Identity & Tools | ERC-8004, hood.ag, HoodLock, Orbio (AI compute credits) |

Pons includes launch discovery (`pons_launch_options`), launch (`pons_launch`), and creator controls (`pons_transfer_creator_fee_recipient`, `pons_set_buyback`) plus curve/graduated trading, graduation, and claims. Catalogs: [`docs/robinhood-chain-projects.md`](docs/robinhood-chain-projects.md) · [`docs/mcp-tools-reference.md`](docs/mcp-tools-reference.md).

## Contracts, Deployments & Pricing

Run `cd contracts && forge test --offline` after installing the pinned contract dependencies and Solidity 0.8.26. Read the [independent review summaries](docs/reviews.md); no audit PDFs ship in this snapshot. `$OAK`, `OakSubscription`, `OakOracle`, and `OakBurner` addresses on `4663` and `46630` are **published at launch** in [`contracts/deployments/4663.json`](contracts/deployments/4663.json) and [`contracts/deployments/46630.json`](contracts/deployments/46630.json) (dormant `OAK` `0x38fE199550E677Fa9caC196495460dfF97BCe28F` is unrelated; `4663` USDG `0x5fc5360d0400a0fd4f2af552add042d716f1d168`, `46630` USDG `0x7E955252E15c84f5768B83c41a71F9eba181802F`, ETH/USDG pool `0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca`, ERC-8004 `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`).

- **Pricing (0% trade fee, no per-call fees):** 30-day USDG cycle (90-day prepay cap; `oak cancel` forfeits remaining days), splitting **25% to `OakBurner`** and **75% to the single-owner treasury wallet**.
- **Holder plan (9 USDG / 30d):** Hold entry-price count `N` of `$OAK`; a one-time sign-up burn burns 5% (`ceil(N * 5 / 100)`) and tracks `N - burn` as `signupOakCount` (e.g., hold 20,000, 1,000 burns, 19,000 tracked). Renewals burn nothing and need no note. Holding `$OAK` buys access and nothing else.
- **No-hold plan (9 USDG + 1/6 entry price / 30d):** **12.333333 USDG** at the $20 floor, re-priced each renewal.
- **Entry curve (`totalSupply()` × `$OAK` USD price; USDG = $1):** <$100k: $20 ($12.33 no-hold); $100k–$500k: $20→$75 ($12.33→$21.50); $500k–$1M: $75→$100 ($21.50→$25.67); $1M–$10M: $100→$300 ($25.67→$59); >$10M: $300 ($59).
- **Phases & 50% guard:** `curve` (`phase != 2`): only no-hold open at `12.333333 USDG`, holder closed. `warmup` (<30m history): both wait. `ready` (>=30m): holder open; 30-minute signed `$OAK` price notes (5-minute life) + on-chain ETH/USDG 30-minute average, guarded within **50% of live pool price**. These are service phases: the oracle itself becomes ready on graduation; the service waits for 30 minutes of history before issuing notes. Contract checks are documented in [security](docs/security.md).

## Contract Deployment Steps

Deployments are operator-controlled and must be rehearsed before any broadcast. From `contracts/`:

1. Install the pinned dependencies, copy `../deploy.env.sample` to an ignored `.env`, and fill the required public addresses and launch parameters locally. The sample contains variable names only and intentionally has no key field.
2. Run `forge build --offline` and `forge test --offline`.
3. Load the local environment and simulate `LaunchOakToken` when a token launch is required. Then simulate `DeployOracle`, `DeployBurner`, and `DeploySubscription` in that order, using `forge script script/<name>.s.sol:<name> --rpc-url "$OAK_RPC_URL"` without `--broadcast`.
4. Verify the simulated chain, immutable addresses, token decimals, signer, payees, predecessor, and transaction previews. Record each deployed address for the next step.
5. Only the human operator may select a local keystore or hardware signer and repeat each reviewed command with `--broadcast`. Never put a private key or recovery phrase in `.env`, command arguments, agent prompts, or logs.

Deployment JSON files are placeholders until an operator records verified receipts. Nothing in this repository deploys automatically.

## Security & Community

Treasury and contract admin is single-owner wallet `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`. One owner key can spend treasury funds, redirect future subscription payments, replace the price signer, and retire subscriptions (no second-signature requirement; cannot spend user balances).

Oak is not affiliated with Robinhood, shows a region notice by default, adds no safety checks or spending caps, and never promises returns.

[`docs/security.md`](docs/security.md) · [`CONTRIBUTING.md`](CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) · [`LICENSE`](LICENSE) · [`LICENSE-PACKAGES.md`](LICENSE-PACKAGES.md) · [@OakAgentKit](https://x.com/OakAgentKit)

Run `oak init --recover` in your own terminal to restore your 24-word backup on a new computer. To replace an existing wallet, use `oak init --recover --replace`; Oak preserves an encrypted backup and asks you to confirm the recovered address. Never enter recovery words in an agent chat, arguments, environment variables or MCP tools.

New automatic wallets support piped MCP with the OS keychain or an owner-only random file key. Backups are optional: run `oak backup` for guidance, and `oak export` only in your own terminal. Automatic wallets have no recovery phrase; recovery accepts the exported private key. Existing passphrase wallets remain unchanged and still need terminal unlock.

Mainnet uses `https://api.oakagentkit.org` by default. Override it with `oak config set OAK_SERVER_URL <https-url>` or `OAK_SERVER_URL`; testnet requires an explicit matching service URL. The deployed service supplies public contract pins via `/v1/config` when needed; explicit overrides remain available. Operators must deploy and upgrade the hosted service before paid actions work.

Headless setup: [automatic and legacy wallet guidance](docs/headless-wallet.md). Deployment JSON files are launch placeholders, not usable configuration.

## Set Up Oak with Any Agent

> Set up Oak for this AI agent. Install @oakagentkit/addon (Node.js 22) and connect the local MCP command `oak mcp`. Call account, tell me the public wallet address and network, and ask me to send a little ETH for gas and USDG. Re-check balances after I fund it. Do not run oak init or oak export, read wallet/key files, or ask for keys or recovery words. Explain identity registration and subscription costs, then get my approval before registering and subscribing. Tell me optional backup guidance with oak backup.

After funding, ask the agent to register a public ERC-8004 identity with `oak_setup {"mode":"register"}`. Oak supplies a default registration-v1 profile; you can provide your own `profile`. Registration costs ETH and publishes the profile. It does not require a subscription. Linking an existing ID uses `oak_setup {"mode":"link","agentId":"<id>"}`; if this wallet owns it, signing is automatic. An external NFT owner must sign in their own terminal because the agent does not control that owner's wallet.

The agent reads `account` for phase and price, explains the recurring payment, and gets your plan approval before calling `oak_subscribe {"plan":"nohold"}` (or `holder`). Launch curve: no-hold only, 12.333333 USDG per 30 days. Warmup: both plans wait for 30 minutes of history. Ready: both plans follow the quoted terms; holder requires OAK and a one-time sign-up burn. `oak_renew {}` reconciles or renews. All transactions retain previews and local signing. Merely funding a wallet does not authorize a paid subscription.

The remaining user steps are funding, authorizing public registration and the recurring plan, and signing for an external identity owner when applicable. These steps move funds, publish data, or require an independently controlled wallet. Read tools remain available without identity or subscription.
