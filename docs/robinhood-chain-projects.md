# Robinhood Chain Ecosystem Projects (25 Configured Modules)

Oak Agent Kit (`@oakagentkit/addon`, published on npm) provides normalized MCP modules for **25 configured ecosystem projects** on **Robinhood Chain mainnet** (chain ID `4663`, `0x1237`).

Instead of configuring 25 separate SDKs or wallets, your agent uses one local wallet (`~/.oak/wallet.enc`), uniform `<module>_<verb>` tool names, decimal base-unit string amounts, finite token approvals (never unlimited), and pre-sign `eth_simulateV1` transaction previews. Swaps approve their quoted input, holder sign-up approves its quoted burn, and bounded-price flows may approve a finite cap followed by cleanup. Since **0.1.1**, local transaction checks and human confirmation precede signing by default. Hosted actions are team-only until token and subscription launch. Projects keep their own protocol fees; Oak charges **0%** on your trades and no per-call fees.

> **Network scope:** All 25 ecosystem modules below operate on Robinhood Chain mainnet (`4663`). Testnet (`46630`) exposes the 9 basic tools, the 3 ERC-8004 identity tools, the 2 local identity lifecycle tools (`oak_setup`, `oak_identity_unlink`), and 2 subscription lifecycle tools (`oak_subscribe`, `oak_renew`): 16 tools total.

> **Qualification scope:** A public-RPC, unsigned-preview sweep measured at least one guarded action in 21 action modules, including Morpho collateral supply, Longbow wrap/deposit, the supported Beefy LP deposit, and Uniswap v3/v4 liquidity addition after allowance-consumption handling was fixed. That does not validate every listed verb: Lighter and HeyResearch are read-only; Merkl claim, Meridian RFQ/settlement, withdrawals, debt changes, fills/exits, creator claims, and ownership-dependent actions were unavailable or unmeasured in that sweep. Combined Relay swap/bridge remains fail-closed; use a separately quoted swap and then bridge. Availability still depends on live project state, wallet authority, service access, and local guard evidence.

---

## 1. Swap and Trade (8 Projects)

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **KyberSwap** | `kyberswap_quote`, `kyberswap_swap` | Aggregator route quoting and exact-approval swap building. Also compared automatically by the generic `quote` and `swap` tools. |
| **Velora** | `velora_quote`, `velora_swap` | Route quoting and swap building with net output comparison and venue fee disclosure. Also included in generic `quote` and `swap`. |
| **Pons** | `pons_browse`, `pons_status`, `pons_launch_options`, `pons_launch`, `pons_transfer_creator_fee_recipient`, `pons_set_buyback`, `pons_graduate`, `pons_buy`, `pons_sell`, `pons_claim` | Full bonding-curve lifecycle, pool graduation (`createGraduatedPool`), graduated Uniswap v4 trading, and creator-fee escrow claims. `pons_buy` and `pons_sell` warn (without blocking) when price impact exceeds 2% against fresh reference prices. |
| **pools.trade** | `poolstrade_launch`, `poolstrade_buy`, `poolstrade_sell`, `poolstrade_collect`, `poolstrade_claim` | Atomic Instant Launch (requiring an explicit permanent `creatorFees` boolean), pool swaps, and creator-fee collection/claims. Token lookups require a contract address. |
| **Clanker** | `clanker_launch`, `clanker_claim`, `clanker_browse` | Clanker v4 token deployment, MEV-window-aware fee locker claims, and indexer launch discovery. Integrated into `find_token` and `positions`. |
| **Hookr** | `hookr_create`, `hookr_cancel`, `hookr_fill`, `hookr_claim_bounty` | Sidecar limit orders on `HookrLimitOrders` with direct agent fill and bounty claims (no Oak keeper). |
| **TickerSpring** | `tickerspring_create`, `tickerspring_cancel`, `tickerspring_claim`, `tickerspring_orders` | Order creation (including `startingPrice` bundles for unopened markets), cancellation, order listing, and on-chain `claimBoth`. |
| **Uniswap Liquidity** | `uniswap_add`, `uniswap_collect`, `uniswap_remove`, `uniswap_list_positions` | Full LP position management across Uniswap `v3` (`NonfungiblePositionManager`) and `v4` (`PositionManager` + `Permit2`). Integrated into one-call `positions`. |

---

## 2. Vaults and Rewards (7 Projects)

All six vault modules integrate into the one-call `positions` tool so an agent can inspect every active vault balance in a single read.

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **Steakhouse** | `steakhouse_list`, `steakhouse_deposit`, `steakhouse_withdraw` | USDG ERC-4626 vault discovery, exact-approval deposits, and withdrawals. |
| **Spark** | `spark_list`, `spark_deposit`, `spark_withdraw` | `spUSDG` ERC-4626 vault discovery, deposits, and withdrawals. |
| **NetNet** | `netnet_list`, `netnet_deposit`, `netnet_withdraw` | `nnUSDG` ERC-4626 vault discovery, deposits, and withdrawals. |
| **Longbow** | `longbow_list`, `longbow_deposit`, `longbow_withdraw` | Core and Frontier USDG and ETH/WETH ERC-4626 vaults. |
| **Grove** | `grove_list`, `grove_deposit`, `grove_withdraw` | Grove x Steakhouse USDG public ERC-4626 vault. |
| **Beefy** | `beefy_list`, `beefy_deposit`, `beefy_withdraw` | UP–WETH vault adapter (`deposit` and `withdraw` shares). |
| **Merkl** | `merkl_rewards`, `merkl_claim` | Campaign reward lookup and cumulative Distributor claims. *Powered by Merkl — [https://app.merkl.xyz](https://app.merkl.xyz)* |

---

## 3. Borrow and Lend (2 Projects)

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **Morpho Blue** | `morpho_supply_collateral`, `morpho_withdraw_collateral`, `morpho_borrow`, `morpho_repay`, `morpho_status` | Collateral supply/withdrawal, borrowing, debt repayment, and market position reads on Morpho Blue. Integrated into `positions`. |
| **Priors** | `priors_lend`, `priors_withdraw`, `priors_borrow`, `priors_repay`, `priors_status` | `CreditPoolV2` lending and withdrawal for all wallets, plus borrowing and repayment for funded ERC-8004 agent credit lines. Integrated into `positions`. |

---

## 4. Move Money (1 Project)

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **Relay** | `relay_bridge_in`, `relay_bridge_out`, `relay_status` | Cross-chain bridging into and out of Robinhood Chain (`4663`). Inbound bridges sign on the quoted origin chain (`OAK_RPC_URL_<chainId>`). Note: `preview` simulates origin-chain transfers and cannot prove off-chain destination settlement; use `relay_status` to track fills. |

---

## 5. Markets and Data (3 Projects)

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **Meridian** | `meridian_browse`, `meridian_positions`, `meridian_settle`, `meridian_redeem`, `meridian_buy`, `meridian_sell` | Prediction market discovery, position reads, settlement/redemption, and multi-turn RFQ auctions using USDe collateral. The local bridge handles multi-turn EIP-712 RFQ continuations automatically (never pass `continuation` or `signature` manually). |
| **Lighter** | `lighter_funding` | Read-only normalized perpetual funding rates. |
| **HeyResearch** | `heyresearch_research_project`, `heyresearch_chain_activity` | Read-only project research and chain activity queries preserving HeyResearch attribution, citations, and status wording. |

---

## 6. Identity and Tools (4 Projects)

| Project | Tools | Capabilities & Protocol Notes |
| :--- | :--- | :--- |
| **ERC-8004** | `erc8004_register`, `erc8004_update`, `erc8004_identity` | On-chain agent identity NFT registration, metadata updates, and ownership lookups on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`). Paired with `oak setup` / `oak_setup` and `oak identity unlink` / `oak_identity_unlink`. |
| **hood.ag** | `hoodag_register`, `hoodag_resolve`, `hoodag_name_info` | Register `.hood` names with USDG, configure primary reverse records, and resolve names and registration metadata. |
| **HoodLock** | `hoodlock_lock`, `hoodlock_burn`, `hoodlock_list_locks`, `hoodlock_airdrop_create`, `hoodlock_airdrop_claim` | Token, v2 LP, and v3 position locks (`unlockTime` capped at `now + 100 years`), token burns, lock queries, and Merkle airdrop creation and claiming (omit `id` on `hoodlock_airdrop_claim` to query eligible airdrops). |
| **Orbio** | `orbio_buy_credit`, `orbio_credit_status` | Purchase AI credits via Orbio Exchange and inspect credit balances on-chain. |

---

## 7. Extending Oak with Declarative Recipes (`oak-recipe/v1`)

Any Robinhood Chain (`4663`) project can ship opt-in declarative JSON recipes (`oak-recipe/v1`) imported with `oak recipes add <pkg-or-path>`. Recipes are strictly data-only (zero third-party code execution) and are displayed to the user and agent as **`as-is, not reviewed by Oak`**. See [`CONTRIBUTING.md`](../CONTRIBUTING.md) for the recipe specification.

---

## Important Trading & Simulation Notes

- **Buyability does not prove sellability:** A token you can buy is not always one you can sell. A successful buy `preview` does not prove you can exit later; transfer restrictions, token taxes, or changing token rules can block a sale.
- **Simulation boundaries:** `preview` (`eth_simulateV1`) simulates on-chain execution at the current block and excludes gas fees. It does not prove off-chain settlement for external relayers (such as Relay cross-chain fills or Meridian RFQ execution).
- **Typed-data paths:** Gasless identity linking/unlinking and Meridian RFQ continuations bind EIP-712 typed data and do not claim an EVM transaction preview. Ask mode confirms typed actions when a signing prompt is required; owner-selected auto mode skips the prompt while retaining the applicable local checks.
