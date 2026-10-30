# MCP Tools Reference

Oak Agent Kit (`@oakagentkit/addon`, available at launch) exposes **102 MCP tools** on **Robinhood Chain mainnet** (`4663`, `0x1237`) before installed recipes: **9 basic tools**, **4 local lifecycle tools**, and **89 ecosystem tools** across **25 projects**, plus dynamic `<project>.<name>` tools for any declarative `oak-recipe/v1` recipes you install.

On **Robinhood Chain Testnet** (`46630`, `0xb626`), the bridge exposes **16 active tools**: the 9 basic tools, the 3 ERC-8004 identity tools, and the 4 local lifecycle tools (`oak_setup`, `oak_identity_unlink`, `oak_subscribe`, and `oak_renew`). Swap routes and the other 24 ecosystem modules are mainnet-only.

---

## Conventions & Entitlements

- **Decimal base-unit strings:** Every token amount in tool inputs and outputs is a decimal base-unit string (for example, `"9000000"` for `9 USDG` with 6 decimals; `"1000000000000000000"` for `1 ETH` or `1 OAK` with 18 decimals). Never pass floating-point numbers.
- **Token metadata:** Tool outputs identify the EIP-55 checksummed token `address` (`0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee` for native ETH), `symbol`, `decimals`, and `chainId` (`4663` or `46630`).
- **Reads vs. actions:** Read tools work without an ERC-8004 identity and even when a subscription is lapsed. Action tools require both a verified ERC-8004 identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`) and an active subscription on the wallet's authoritative lineage contract.
- **Pre-sign preview & exact approvals:** Every action tool runs `preview` (`eth_simulateV1` with `traceTransfers: true`) before signing locally, reuses a matching same-block preview within 12 seconds so `swap` does not simulate twice, and builds exact token approvals (`amountIn`) — never unlimited approvals.

---

## Basic Tools (9)

| Tool | One-line public description |
| :--- | :--- |
| `find_token` | Find verified tokens by name, symbol or address; return unverified matches and warnings separately. |
| `balances` | Read native ETH and configured token/stock balances in one multicall. |
| `price` | Read token USD price, token metadata and staleness. |
| `quote` | Quote the best supported swap route for exact input base units and slippage. |
| `swap` | Build the saved quote, inspect/reuse preview, then sign locally and broadcast exact approvals and swap. |
| `preview` | Simulate an unsigned transaction sequence and report token/native transfer changes (gas excluded). |
| `history` | Read recent wallet subscription and ecosystem contract events. |
| `positions` | Read wallet positions across all configured ecosystem modules. |
| `account` | Read subscription, holdings requirement, launch phase and indicative plan state. |

---

## Local Lifecycle Tools (4)

| Tool | One-line public description |
| :--- | :--- |
| `oak_setup` | Register or link an ERC-8004 ID; external-owner signing stays in the owner terminal. |
| `oak_identity_unlink` | Revoke the linked identity without gas; owner revocation requires owner-terminal signing. |
| `oak_subscribe` | Start a recurring holder or no-hold subscription after user approval; preview and sign locally. |
| `oak_renew` | Reconcile or renew the current subscription with local signing. |

---

## 25 Ecosystem Project Modules (89 Tools)

### 1. KyberSwap (2)

| Tool | One-line public description |
| :--- | :--- |
| `kyberswap_quote` | Quote an exact-input swap through KyberSwap. |
| `kyberswap_swap` | Execute a saved KyberSwap quote through local preview/signing. |

### 2. Velora (2)

| Tool | One-line public description |
| :--- | :--- |
| `velora_quote` | Quote an exact-input swap through Velora. |
| `velora_swap` | Execute a saved Velora quote through local preview/signing. |

### 3. Steakhouse (3)

| Tool | One-line public description |
| :--- | :--- |
| `steakhouse_list` | List supported Steakhouse vaults and their configuration. |
| `steakhouse_deposit` | Prepare a deposit into a supported Steakhouse vault. |
| `steakhouse_withdraw` | Prepare withdrawal from a supported Steakhouse vault. |

### 4. Spark (3)

| Tool | One-line public description |
| :--- | :--- |
| `spark_list` | List supported Spark vaults and their configuration. |
| `spark_deposit` | Prepare a deposit into a supported Spark vault. |
| `spark_withdraw` | Prepare withdrawal from a supported Spark vault. |

### 5. NetNet (3)

| Tool | One-line public description |
| :--- | :--- |
| `netnet_list` | List supported Netnet vaults and their configuration. |
| `netnet_deposit` | Prepare a deposit into a supported Netnet vault. |
| `netnet_withdraw` | Prepare withdrawal from a supported Netnet vault. |

### 6. Longbow (3)

| Tool | One-line public description |
| :--- | :--- |
| `longbow_list` | List supported Longbow vaults and their configuration. |
| `longbow_deposit` | Prepare a deposit into a supported Longbow vault. |
| `longbow_withdraw` | Prepare withdrawal from a supported Longbow vault. |

### 7. Grove (3)

| Tool | One-line public description |
| :--- | :--- |
| `grove_list` | List supported Grove vaults and their configuration. |
| `grove_deposit` | Prepare a deposit into a supported Grove vault. |
| `grove_withdraw` | Prepare withdrawal from a supported Grove vault. |

### 8. Beefy (3)

| Tool | One-line public description |
| :--- | :--- |
| `beefy_list` | List supported Beefy vaults and their configuration. |
| `beefy_deposit` | Prepare a deposit into a supported Beefy vault. |
| `beefy_withdraw` | Prepare withdrawal from a supported Beefy vault. |

### 9. Pons (10)

| Tool | One-line public description |
| :--- | :--- |
| `pons_browse` | Browse Pons launches using supported filters. |
| `pons_status` | Read Pons token launch, curve and graduation status. |
| `pons_launch_options` | Read Pons launch eligibility, fee, tax cap, launch configs and approved pair token economics. |
| `pons_transfer_creator_fee_recipient` | Prepare transfer of future Pons creator fees and the buyback vest beneficiary to a new recipient. |
| `pons_set_buyback` | Prepare enabling or disabling Pons creator-fee buybacks for a launched token. |
| `pons_launch` | Prepare a new Pons launch and disclose creator fees. |
| `pons_graduate` | Prepare graduation for a launch eligible to create its pool. |
| `pons_buy` | Quote/build a Pons curve token purchase with price-impact warning and exact input. |
| `pons_sell` | Quote/build a Pons curve token sale with price-impact warning and exact input. |
| `pons_claim` | Prepare claim of eligible Pons launch creator fees. |

### 10. Orbio (2)

| Tool | One-line public description |
| :--- | :--- |
| `orbio_buy_credit` | Prepare purchase of Orbio credits. |
| `orbio_credit_status` | Read Orbio credit state. |

### 11. HoodLock (5)

| Tool | One-line public description |
| :--- | :--- |
| `hoodlock_lock` | Prepare a supported token or liquidity-position lock. |
| `hoodlock_burn` | Prepare a supported token burn. |
| `hoodlock_list_locks` | Read supported wallet token/liquidity locks. |
| `hoodlock_airdrop_create` | Prepare an airdrop and return its recipient/proof data. |
| `hoodlock_airdrop_claim` | Discover eligible airdrops when id is omitted, or prepare a proof-based claim. |

### 12. Merkl (2)

| Tool | One-line public description |
| :--- | :--- |
| `merkl_rewards` | Read claimable rewards (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_claim` | Claim rewards on Merkl (Powered by Merkl — https://app.merkl.xyz). |

### 13. Relay (3)

| Tool | One-line public description |
| :--- | :--- |
| `relay_bridge_out` | Prepare an outbound Relay bridge route from Robinhood Chain. |
| `relay_status` | Read Relay bridge execution/fill status; preview cannot prove destination settlement. |
| `relay_bridge_in` | Prepare an inbound Relay bridge route to Robinhood Chain. |

### 14. Lighter (1)

| Tool | One-line public description |
| :--- | :--- |
| `lighter_funding` | Read Lighter funding data without submitting trades. |

### 15. ERC-8004 (3)

| Tool | One-line public description |
| :--- | :--- |
| `erc8004_register` | Prepare ERC-8004 identity registration. |
| `erc8004_update` | Prepare an update to an owned ERC-8004 agent registration. |
| `erc8004_identity` | Read ERC-8004 agent identity and ownership. |

### 16. hood.ag (3)

| Tool | One-line public description |
| :--- | :--- |
| `hoodag_register` | Prepare hood.ag name registration. |
| `hoodag_resolve` | Resolve a hood.ag name. |
| `hoodag_name_info` | Read hood.ag name registration information. |

### 17. HeyResearch (2)

| Tool | One-line public description |
| :--- | :--- |
| `heyresearch_research_project` | Read project research from HeyResearch, retaining returned citations and links. |
| `heyresearch_chain_activity` | Read chain activity from HeyResearch, retaining attribution. |

### 18. Priors (5)

| Tool | One-line public description |
| :--- | :--- |
| `priors_lend` | Prepare lending assets into Priors. |
| `priors_withdraw` | Prepare withdrawal from Priors lending. |
| `priors_borrow` | Prepare a Priors borrowing operation. |
| `priors_repay` | Prepare repayment of Priors debt. |
| `priors_status` | Read Priors lending/borrowing account state. |

### 19. Morpho Blue (5)

| Tool | One-line public description |
| :--- | :--- |
| `morpho_supply_collateral` | Prepare collateral supply to a Morpho Blue market. |
| `morpho_withdraw_collateral` | Prepare collateral withdrawal from Morpho Blue. |
| `morpho_borrow` | Prepare borrowing from a Morpho Blue market. |
| `morpho_repay` | Prepare repayment to a Morpho Blue market. |
| `morpho_status` | Read Morpho Blue market/account state. |

### 20. Uniswap Liquidity (4)

| Tool | One-line public description |
| :--- | :--- |
| `uniswap_add` | Prepare Uniswap liquidity addition for version v3 or v4. |
| `uniswap_collect` | Prepare Uniswap v3/v4 position fee collection. |
| `uniswap_remove` | Prepare Uniswap v3/v4 liquidity removal. |
| `uniswap_list_positions` | Read Uniswap v3/v4 liquidity positions. |

### 21. Hookr (4)

| Tool | One-line public description |
| :--- | :--- |
| `hookr_create` | Prepare a Hookr sidecar limit order. |
| `hookr_cancel` | Prepare Hookr order cancellation. |
| `hookr_fill` | Prepare fill of an eligible Hookr order. |
| `hookr_claim_bounty` | Prepare an eligible Hookr bounty claim. |

### 22. Meridian (6)

| Tool | One-line public description |
| :--- | :--- |
| `meridian_browse` | Browse Meridian prediction markets. |
| `meridian_positions` | Read Meridian prediction positions. |
| `meridian_settle` | Prepare settlement of eligible Meridian positions. |
| `meridian_redeem` | Prepare redemption of resolved Meridian positions. |
| `meridian_buy` | Prepare a Meridian buy with bridge-managed EIP-712 RFQ continuation/signing. |
| `meridian_sell` | Prepare a Meridian sell with bridge-managed EIP-712 RFQ continuation/signing. |

### 23. TickerSpring (4)

| Tool | One-line public description |
| :--- | :--- |
| `tickerspring_create` | Prepare a TickerSpring order, including unopened-market starting-price bundles. |
| `tickerspring_cancel` | Prepare TickerSpring order cancellation. |
| `tickerspring_claim` | Prepare TickerSpring order proceeds/token claim. |
| `tickerspring_orders` | Read TickerSpring wallet orders. |

### 24. Clanker (3)

| Tool | One-line public description |
| :--- | :--- |
| `clanker_launch` | Prepare a Clanker token launch. |
| `clanker_claim` | Prepare an eligible Clanker creator-fee claim. |
| `clanker_browse` | Browse Clanker token launches. |

### 25. pools.trade (5)

| Tool | One-line public description |
| :--- | :--- |
| `poolstrade_launch` | Prepare a pools.trade token launch. |
| `poolstrade_buy` | Prepare a pools.trade token purchase. |
| `poolstrade_sell` | Prepare a pools.trade token sale. |
| `poolstrade_collect` | Prepare pools.trade creator-fee collection. |
| `poolstrade_claim` | Prepare an eligible pools.trade claim. |

---

## Declarative Project Recipes (`oak-recipe/v1`)

| Tool | One-line public description |
| :--- | :--- |
| `<project>.<name>` | Run an installed data-only recipe, labelled as-is, not reviewed by Oak; names depend on installed recipes. |

## Automatic Wallet and Paid Setup

`account {}` always includes the local public address, network, ETH/USDG funding message, region notice and optional backup guidance, even when hosted subscription status is unavailable. Re-check `balances` after the user funds the address. `oak_setup {"mode":"register"}` supplies a default public profile; registration requires user authorization and ETH for gas.

`oak_subscribe {"plan":"nohold"}` or `oak_subscribe {"plan":"holder"}` previews and locally signs a subscription after the user approves the recurring payment. `oak_renew {}` reconciles or renews the current plan. Both require verified identity. `oak backup` prints guidance; never run `oak export` or recovery through an agent.
