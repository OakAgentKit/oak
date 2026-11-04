# MCP Tools Reference

Oak Agent Kit (`@oakagentkit/addon` 0.2.4, published on npm) exposes **684 MCP tools** on **Robinhood Chain mainnet** (`4663`, `0x1237`) before installed recipes: **9 basic tools**, **2 finder tools**, **12 local lifecycle tools**, and **661 ecosystem tools** across **28 configured projects**, plus dynamic `<project>.<name>` tools for any declarative `oak-recipe/v1` recipes you install.

`tools/list` stays short. It shows the **97** tools marked *yes* below (each program's everyday tools, the local lifecycle tools, `find_tool` and `run_tool`) plus installed recipes. Every other tool is reachable by name: `find_tool` searches all 684 by what you want to do, and `run_tool` calls one with its arguments through the same code path as a direct call, so the access gate, local guard, preview, exact approvals and human confirmation are unchanged and reads stay free.

On **Robinhood Chain Testnet** (`46630`, `0xb626`), the bridge exposes **42 active tools**, **22** listed in `tools/list`: the 9 basic tools, `find_tool` and `run_tool`, the 19 ERC-8004 identity tools, and the 12 local lifecycle tools (`oak_setup`, `oak_identity_unlink`, `oak_subscribe`, `oak_renew`, `oak_redeem`, `send`, `oak_confirmation`, `oak_cleanup_allowances`, `oak_allowances`, `oak_approval_census_status`, `oak_receipts` and `oak_playbook`). Swap routes and the other 27 ecosystem modules are mainnet-only.

---

## Conventions & Entitlements

- **Decimal base-unit strings:** Every token amount in tool inputs and outputs is a decimal base-unit string (for example, `"9000000"` for `9 USDG` with 6 decimals; `"1000000000000000000"` for `1 ETH` or `1 OAK` with 18 decimals). Never pass floating-point numbers.
- **Token metadata:** Tool outputs identify the EIP-55 checksummed token `address` (`0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee` for native ETH), `symbol`, `decimals`, and `chainId` (`4663` or `46630`).
- **Reads vs. actions:** Read tools work without an ERC-8004 identity and even when a subscription is lapsed. Action tools require both a verified ERC-8004 identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`) and an active subscription on the wallet's authoritative lineage contract. One narrow exception: a fresh wallet may run `relay_bridge_in` to itself for ETH or USDG on Robinhood Chain (no swap) before it has either, so funds on another chain can reach it; that bridge still previews, passes the local guard and asks for confirmation. `find_tool` reports each tool as read or action by this same rule.
- **Private hosted access:** Installing or listing tools does not grant action access. A stranger can call read tools such as `find_token`; an unallowlisted private-mode action returns "Not submitted. This wallet is not on the server private test allow-list. Ask the operator to configure private test access or use the normal paid setup." Mainnet paid access is live; it requires a verified ERC-8004 identity and an active subscription. Call `account` for phase, available plans and price.
- **Hosted preview vs. local simulations:** Transaction builders run a hosted `preview` (`eth_simulateV1` with `traceTransfers: true`). The bridge may reuse an identical same-block hosted preview for up to 12 seconds, but this does not remove the sender's local ordered simulation, exact-transaction simulation, or fresh post-confirmation simulation. Transfer changes are estimates, exclude gas, and cannot prove inclusion, sellability, or external settlement.
- **Finite approvals:** Swaps approve the quoted input and holder sign-up approves the quoted burn. Bounded-price flows may approve a finite capped maximum and request cleanup afterward. Unlimited grants are refused, but Oak makes no unconditional promise that every successful flow leaves zero residual allowance.
- **Typed data and gasless paths:** Identity link/unlink challenges and Meridian RFQ continuations sign EIP-712 typed data rather than an EVM transaction, so they do not claim a transaction preview or gas estimate. Ask mode binds confirmation to the typed-data hash when a prompt is required; owner-selected auto mode skips prompts while retaining applicable checks. Reads and session/request authentication signatures do not prompt.

---

## Basic Tools (9)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `find_token` | yes | Find verified tokens by name, symbol or address; return unverified matches and warnings separately. |
| `balances` | yes | Read native ETH, configured tokens/stocks, and held ERC-20s received through locally journaled Oak transactions. Amounts are current RPC base units; extra token symbols are untrusted text. |
| `price` | yes | Read token USD price, token metadata and staleness. |
| `quote` | yes | Quote the best supported swap route for exact input base units and slippage. |
| `swap` | yes | Build the saved quote, inspect/reuse preview, then sign locally and broadcast the quoted-input approval and swap. |
| `preview` | via `run_tool` | Simulate an unsigned transaction sequence and estimate token/native transfer changes (gas and external settlement excluded). |
| `history` | via `run_tool` | Read recent supported wallet events; RPC log/indexer results may lag and swaps are not comprehensively covered. Pass transactionHash to history for a direct eth_getTransactionReceipt check on the configured Oak chain, then check balances or program status. |
| `positions` | yes | Read wallet positions with a 10-second per-program deadline; returns positions, per-program status and incomplete program names. Incomplete never means zero holdings. Call when the person asks what they hold; report every entry and relay any oakNotice as written. |
| `account` | yes | Read subscription, holdings requirement, launch phase and indicative plan state. |

---

## Finder Tools (2)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `find_tool` | yes | Search every Oak tool, listed or not, by what you want to do (for example "remove uniswap liquidity") or by exact name; returns names, one-line descriptions, read or action, and required inputs, plus the full input schema for an exact name. |
| `run_tool` | yes | Run any Oak tool by name with its arguments, including tools find_tool returns that are not listed. Exactly the checks of a direct call apply: reads stay free; actions keep the access gate, local guard, preview, exact approvals and human confirmation. |

---

## Local Lifecycle Tools (12)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `oak_setup` | yes | Register or link an ERC-8004 ID; external-owner signing stays in the owner terminal. |
| `oak_identity_unlink` | yes | Revoke the linked identity without gas; owner revocation requires owner-terminal signing. |
| `oak_subscribe` | yes | Start an authorized recurring holder or no-hold subscription with local preview and signing. |
| `oak_renew` | yes | Reconcile or renew an existing subscription with local preview and signing. |
| `oak_redeem` | yes | Redeem a Verified Builder code (oak_redeem {code}) for 30 free days on this wallet: no Oak plan fee or $OAK holding until the date shown; gas, project fees and capital stay yours, and one code activates one wallet. Needs no identity or plan, so run it before oak setup. A code typed in a terminal can stay in shell history and one pasted into an agent conversation stays there; Oak never writes it to its own logs, receipts or configuration. |
| `send` | yes | Send ETH or a pinned token (USDG, WETH, USDe, OAK) from the local wallet to an address. A human confirms the exact token, amount and recipient before signing. |
| `oak_confirmation` | yes | Read the decoded terms and unsigned hashes of pending human confirmations in this local process. Cannot approve or sign. No identity or subscription needed. |
| `oak_cleanup_allowances` | yes | Separate wallet allowance cleanup: preview and confirm each recorded leftover approval revoke. Costs network fees. Never bundled into an unrelated action. No identity or subscription needed. |
| `oak_allowances` | yes | Read current ERC-20 and Permit2 allowances from the local wallet to known Oak spenders at one block. Optional tokens array; defaults include pinned tokens and Beefy wants/shares. Flags token-level default Permit2 approvals separately from wallet permissions; defaults are not wallet-made grants and should not be advised for revocation. Unavailable reads remain unknown. No identity, subscription, signing or cleanup. |
| `oak_approval_census_status` | yes | Read local approval-history catch-up progress and estimated time. Uniswap and reads remain available during catch-up. |
| `oak_receipts` | yes | List or export local approval receipts as JSON or CSV, or verify their hash chain against a saved head. No upload, signing, identity or subscription required. |
| `oak_playbook` | yes | Read an Oak playbook by name, such as reads or pendle, for clients that cannot read MCP resources. No name lists the playbooks; a long playbook gives a nextOffset to pass back as offset. Local and read-only. |

---

## 28 Ecosystem Project Modules (661 Tools)

### 1. KyberSwap (2)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `kyberswap_quote` | via `run_tool` | Quote an exact-input swap through KyberSwap. |
| `kyberswap_swap` | via `run_tool` | Execute a saved KyberSwap quote through local preview/signing. |

### 2. Velora (11)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `velora_quote` | via `run_tool` | Quote an exact-input swap through Velora. |
| `velora_swap` | via `run_tool` | Execute a saved Velora quote through local preview/signing. |
| `velora_delta_token_support` | via `run_tool` | Read whether Velora Delta supports a token on Robinhood Chain. |
| `velora_delta_orders` | via `run_tool` | Read this wallet's Velora Delta orders on Robinhood Chain, filtered by type, status or order family, page by page. |
| `velora_delta_order` | via `run_tool` | Read one of this wallet's Velora Delta orders by ID, with its fill and refund transaction hashes. |
| `velora_delta_bridge_routes` | via `run_tool` | Read the Velora Delta bridge routes that touch Robinhood Chain; nothing is bridged. |
| `velora_delta_bridge_protocols` | via `run_tool` | Read the bridge protocols Velora Delta lists as active; nothing is bridged. |
| `velora_delta_strategies` | via `run_tool` | Read Velora's Robinhood Chain dToken and vault strategy catalogue; listed rates are provider estimates, not promised returns. |
| `velora_fee_balance` | via `run_tool` | Read this wallet's claimable Velora partner fee balance for one ERC-20 token, from Market or Delta fees. |
| `velora_claim_fees` | via `run_tool` | Prepare claiming this wallet's accrued Velora partner fees for one ERC-20 token (Market or Delta) to this same wallet; no approval is needed. |
| `velora_unwrap_deth` | via `run_tool` | Prepare redeeming wallet-held dETH for native ETH 1:1 to this same wallet; it cannot release an active order's escrow. |

### 3. Steakhouse (8)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `steakhouse_details` | via `run_tool` | Read the Steakhouse vault's adapter markets, available liquidity, force-exit penalties, owner, curator and fees at one block. |
| `steakhouse_analytics` | via `run_tool` | Read Steakhouse vault historical APY, allocations, history or pending governance actions from Morpho's API; indexed data can lag. |
| `steakhouse_manage` | via `run_tool` | Prepare a role-gated Steakhouse vault operation, such as naming a new owner, curator or fee recipient, setting fees or caps, or allocating; timelocked changes are submitted first. |
| `steakhouse_mint` | via `run_tool` | Prepare minting an exact number of Steakhouse vault shares, with an exact USDG approval and a maximum-assets limit. |
| `steakhouse_redeem` | via `run_tool` | Prepare redeeming an exact number of Steakhouse vault shares for USDG. |
| `steakhouse_list` | via `run_tool` | List supported Steakhouse vaults and their configuration. |
| `steakhouse_deposit` | yes | Prepare a deposit into a supported Steakhouse vault. |
| `steakhouse_withdraw` | yes | Prepare withdrawal from a supported Steakhouse vault. |

### 4. Spark (10)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `spark_details` | via `run_tool` | Read the Spark vault's savings rate, annual projection, deposit cap, idle USDG and this wallet's position value at one block; the projection is not a promised return. |
| `spark_roles` | via `run_tool` | Read who holds the Spark vault's admin, setter and taker roles. |
| `spark_manage` | via `run_tool` | Prepare a role-gated Spark vault operation: drip, set the rate, rate bounds or deposit cap, take liquidity, grant, revoke or renounce a role (granting names a new role holder), or upgrade. |
| `spark_mint` | via `run_tool` | Prepare minting an exact number of Spark vault shares, with an exact USDG approval, a maximum-assets limit and an optional referral label. |
| `spark_redeem` | via `run_tool` | Prepare redeeming an exact number of Spark vault shares for USDG. |
| `spark_deposit_referral` | via `run_tool` | Prepare a Spark vault deposit that carries a numeric referral label; the label is an event field, not a points claim. |
| `spark_return_liquidity` | via `run_tool` | Prepare sending USDG straight to the Spark vault as returned liquidity; it mints no shares and is not a deposit. |
| `spark_list` | via `run_tool` | Read Spark vault configuration, wallet share balance and asset valuation. Fewer spUSDG shares than deposited USDG is an exchange rate, not a loss; compare convertToAssets and previewRedeem. |
| `spark_deposit` | yes | Prepare a deposit into a supported Spark vault. |
| `spark_withdraw` | yes | Prepare withdrawal from a supported Spark vault. |

### 5. LayerBank (3)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `layerbank_list` | via `run_tool` | Read live LayerBank USDG rates, bonus end date, cash on hand, supply-cap room and wallet receipts. Show the returned risk and cost lines. |
| `layerbank_deposit` | yes | Prepare lending a USDG base-unit amount on LayerBank. Rates are read live and can change; show the returned risk and cost lines before asking. |
| `layerbank_withdraw` | yes | Prepare taking USDG out of LayerBank, limited by cash on hand. Use a base-unit amount or max; show the returned receipt and network cost. |

### 6. Pendle (4)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `pendle_list` | via `run_tool` | Read live verified Pendle fixed terms, rates, end dates and wallet PT balances. Stock terms pay stock units, not fixed dollars; include_ended shows ended terms. |
| `pendle_buy` | yes | Prepare a Pendle PT purchase with the verified market input token. Rates are read live; show the end date, early-exit risk, costs and minimum PT receipt. |
| `pendle_sell` | yes | Prepare an early Pendle PT exit to its input token, using a PT base-unit amount or max. Show the live price and possible loss; default to keeping the term. |
| `pendle_redeem` | yes | Prepare cashing out an ended Pendle term, or all ended terms, using locally built calldata. Stock terms pay the stock token; swapping to USDG is separate. |

### Helper: Earn options (1)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `earn_options` | yes | Read live LayerBank and Pendle options for make my money earn something. Read the returned card, risks, costs and maturity notices as written; let the user pick. |

### 7. NetNet (26)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `netnet_list` | via `run_tool` | List supported Netnet vaults and their configuration. |
| `netnet_deposit` | yes | Prepare a deposit into a supported Netnet vault. |
| `netnet_withdraw` | yes | Prepare withdrawal from a supported Netnet vault. |
| `netnet_staking_status` | via `run_tool` | Read NetNet staking epoch, distributions, balances and pending warmup claims. |
| `netnet_claim_stake` | via `run_tool` | Prepare a matured NetNet staking warmup claim to this wallet. |
| `netnet_rebase` | via `run_tool` | Prepare permissionless due-epoch NetNet staking rebase and oracle maintenance. |
| `netnet_stake` | via `run_tool` | Prepare staking NET 1:1 into rebasing sNET, optionally wrapping to wsNET in the same call through NetNet's Zap. |
| `netnet_wrap` | via `run_tool` | Prepare wrapping sNET into non-rebasing wsNET, the collateral for NetNet's Loopback borrow market. |
| `netnet_unwrap` | via `run_tool` | Prepare unwrapping wsNET back into sNET. |
| `netnet_unstake` | via `run_tool` | Prepare unstaking sNET back into NET. |
| `netnet_financial_status` | via `run_tool` | Read NetNet founding and primary bonds, inverse buybacks, treasury NAV, pTEAM options, RWA notes, premium sales and tax accounting. |
| `netnet_financial_action` | via `run_tool` | Prepare NetNet bond purchase or redemption, buyback, pTEAM exercise, treasury reserve operations, RWA management or premium/tax keepers. |
| `netnet_desk_read` | via `run_tool` | Read verified NetNet desk ABI catalogs and exact view methods for futures, underwriting, WinNET, games, prices, distribution and router state. |
| `netnet_card_read` | via `run_tool` | Read matched TURBO, blackjack or feed ABI catalogs and exact public methods; whole-card counts, series, basis, sessions, claims and contract hashes. Never signs or moves cards. |
| `netnet_card_capabilities` | via `run_tool` | Show active NetNet card reads and self-only recovery, remaining action candidates, and why collection approvals, new blackjack play and unqualified signatures or conversions are refused. |
| `netnet_blackjack_finalize` | via `run_tool` | Finalize this wallet’s due Closing blackjack session and recover its last on-chain cards, with local human confirmation. |
| `netnet_blackjack_expire` | via `run_tool` | Expire this wallet’s due Open blackjack session and recover its last on-chain cards, with local human confirmation. |
| `netnet_blackjack_claim` | via `run_tool` | Claim this wallet’s parked blackjack cards for one original series, with local human confirmation. |
| `netnet_desk_action` | via `run_tool` | Prepare finite NetNet tNET test futures or underwriting, WinNET entry/lock/exit, or canonical-pair oracle checkpoint. |
| `netnet_details` | via `run_tool` | Read NetNet Credit allocation book, exit capacity, fees and vault roles at one block. |
| `netnet_analytics` | via `run_tool` | Read indexed NetNet Credit APY, allocation history or pending governance with explicit outage handling. |
| `netnet_manage` | via `run_tool` | Prepare role-checked NetNet Credit V2 vault configuration or timelock submission/revocation. |
| `netnet_mint` | via `run_tool` | Prepare exact-share NetNet Credit minting with a bounded asset approval. |
| `netnet_redeem` | via `run_tool` | Prepare redemption of exact NetNet Credit shares to this wallet. |
| `netnet_force_exit` | via `run_tool` | Prepare a penalized NetNet Credit deallocation and cash exit with preview limits. |
| `netnet_in_kind_exit` | via `run_tool` | Prepare a bounded NetNet Credit in-kind exit into idle USDG and supported Morpho Blue supply positions, with exact share approval. |

### 8. Longbow (28)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `longbow_list` | yes | List supported Longbow vaults and their configuration. |
| `longbow_deposit` | yes | Prepare a deposit into a supported Longbow vault. |
| `longbow_withdraw` | yes | Prepare withdrawal from a supported Longbow vault, including the withdraw-only V1 vaults. |
| `longbow_staking_status` | via `run_tool` | Read BOW stake, earned USDG, reward rate, period, pause, cooldown and staking roles. |
| `longbow_manage_staking` | via `run_tool` | Prepare staking owner/distributor reward funding, duration, cooldown, pause, recovery or ownership operations. |
| `longbow_stake` | via `run_tool` | Prepare staking BOW for USDG rewards, with an exact approval and no lock or cooldown. |
| `longbow_unstake` | via `run_tool` | Prepare unstaking BOW; all returns the whole stake and claims rewards in one call. |
| `longbow_claim_rewards` | via `run_tool` | Prepare claiming earned USDG staking rewards while keeping the BOW staked. |
| `longbow_nft_listings` | via `run_tool` | Read public NFT borrowing listings; listing text is untrusted and no offer liquidity is promised. |
| `longbow_nft_offers` | via `run_tool` | Read a public NFT listing offer book without signing or publishing. |
| `longbow_nft_loan` | via `run_tool` | Read exact NFT loan payoff, collateral, borrower, maturity and on-chain settlement state. |
| `longbow_nft_loans` | via `run_tool` | Read indexed borrower or lender loan IDs and verify them against the pinned NFT loan contract. |
| `longbow_nft_accept_offer` | via `run_tool` | Prepare borrower acceptance of a qualified fixed NFT loan using approval for exactly one NFT; human loss/deadline confirmation is mandatory. |
| `longbow_nft_repay` | via `run_tool` | Prepare an exact-payoff qualified NFT loan repayment before maturity to recover collateral. |
| `longbow_rebates` | via `run_tool` | Read funded borrow-rebate epochs, wallet claim flags and expiry without inventing a publisher proof. |
| `longbow_claim_rebate` | via `run_tool` | Prepare a wallet-bound USDG borrow-rebate proof claim against the current on-chain epoch. |
| `longbow_manage_rebates` | via `run_tool` | Prepare publisher funding or owner publisher, expired-epoch sweep and ownership operations. |
| `longbow_nft_admin` | via `run_tool` | Read Longbow NFT loan owner, pause state, maximum duration, fee and currency permissions. |
| `longbow_manage_nft` | via `run_tool` | Prepare role-checked NFT loan pause, fee, duration, currency-permission or ownership-lifecycle administration. |
| `longbow_referral` | via `run_tool` | Read wallet-bound public referral statistics and unverified bonus estimates without registration, linking or publication. |
| `longbow_fixed_offers` | via `run_tool` | Read and decode historical Longbow Midnight fixed-rate offer publications; report incomplete data and direct-builder support. |
| `longbow_details` | via `run_tool` | Read current Longbow V2 allocation book, exit capacity, fees and vault roles. |
| `longbow_analytics` | via `run_tool` | Read Longbow published percent APY separately from indexed historical APY, allocations, history or pending governance; unavailable data remains explicit. |
| `longbow_manage` | via `run_tool` | Prepare role-checked Longbow V2 vault configuration or timelock submission/revocation. |
| `longbow_mint` | via `run_tool` | Prepare exact-share Longbow V2 minting with a bounded underlying-asset approval. |
| `longbow_withdraw_assets` | via `run_tool` | Prepare an exact-underlying-amount Longbow V2 withdrawal to this wallet. |
| `longbow_force_exit` | via `run_tool` | Prepare a penalized Longbow V2 deallocation and cash exit with preview limits. |
| `longbow_in_kind_exit` | via `run_tool` | Prepare a bounded Longbow V2 in-kind exit into idle assets and supported Morpho Blue supply positions, with exact share approval. |

### 9. Grove (8)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `grove_details` | via `run_tool` | Read the Grove vault's adapter markets, available liquidity, force-exit penalties, owner, curator and fees at one block. |
| `grove_analytics` | via `run_tool` | Read Grove vault historical APY, allocations, history or pending governance actions from Morpho's API; indexed data can lag. |
| `grove_manage` | via `run_tool` | Prepare a role-gated Grove vault operation, such as naming a new owner, curator or fee recipient, setting fees or caps, or allocating; timelocked changes are submitted first. |
| `grove_mint` | via `run_tool` | Prepare minting an exact number of Grove vault shares, with an exact USDG approval and a maximum-assets limit. |
| `grove_withdraw_assets` | via `run_tool` | Prepare withdrawing an exact USDG amount from the Grove vault, burning the shares needed. |
| `grove_list` | via `run_tool` | List supported Grove vaults and their configuration. |
| `grove_deposit` | yes | Prepare a deposit into a supported Grove vault. |
| `grove_withdraw` | yes | Prepare withdrawal from a supported Grove vault. |

### 10. Beefy (16)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `beefy_list` | yes | List supported Beefy vaults and their configuration. |
| `beefy_vault_info` | via `run_tool` | Read a Beefy vault's configuration, strategy, price per share and optional APY/TVL history buckets. |
| `beefy_deposit` | yes | Prepare a deposit into a supported Beefy vault. |
| `beefy_withdraw` | yes | Prepare withdrawal from a supported Beefy vault. |
| `beefy_lp` | via `run_tool` | Read Beefy vAMM or CLM pool metadata and holdings; optionally plan a CLM bridge-token entry budget. |
| `beefy_swap` | via `run_tool` | Prepare a swap between a Beefy LP vault's pool tokens with a slippage bound. |
| `beefy_add_liquidity` | via `run_tool` | State oak.lpWarning first before preparing any liquidity addition. Prepare adding both pool tokens to a Beefy LP vault's pool with a slippage bound. |
| `beefy_remove_liquidity` | via `run_tool` | Prepare removing liquidity from a Beefy LP vault's pool with a slippage bound. |
| `beefy_clm_swap` | via `run_tool` | Prepare a pinned CLM constituent or USDG/WETH swap, including native ETH wrapping, with an output minimum. |
| `beefy_clm_deposit` | via `run_tool` | State oak.lpWarning first before preparing any liquidity addition. Prepare minting CLM manager shares from constituent tokens with exact approvals and a share minimum. |
| `beefy_clm_withdraw` | via `run_tool` | Prepare redeeming CLM manager shares to constituent tokens with output minimums. |
| `beefy_boosts` | via `run_tool` | List Beefy boost (extra reward) pools and their configuration. |
| `beefy_boost` | via `run_tool` | Prepare staking in, withdrawing from, claiming from or exiting a Beefy boost pool. |
| `beefy_boost_manage` | via `run_tool` | Prepare a manager-only Beefy boost action such as notifying or removing rewards, rescuing tokens or changing the manager or owner. |
| `beefy_vault_admin` | via `run_tool` | Read who owns, manages and can operate a Beefy vault and its strategy. |
| `beefy_vault_manage` | via `run_tool` | Prepare a role-gated Beefy vault action such as earn, strategy proposal or upgrade, token rescue or ownership change. |

### 11. Pons (18)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `pons_browse` | yes | Browse Pons launches, search them by name, symbol or address, or list all newest first; every result is re-read on chain. |
| `pons_status` | via `run_tool` | Read Pons token launch, curve and graduation status. |
| `pons_launch_options` | via `run_tool` | Read Pons launch eligibility, fee, tax cap, launch configs and approved pair token economics. |
| `pons_transfer_creator_fee_recipient` | via `run_tool` | Prepare transfer of future Pons creator fees and the buyback vest beneficiary to a new recipient. |
| `pons_set_buyback` | via `run_tool` | Prepare enabling or disabling Pons creator-fee buybacks for a launched token. |
| `pons_launch` | yes | Prepare a new Pons launch and disclose creator fees. |
| `pons_graduate` | via `run_tool` | Prepare graduation for a launch eligible to create its pool. |
| `pons_buy` | yes | Quote/build a Pons curve token purchase with price-impact warning and exact input. |
| `pons_sell` | yes | Quote/build a Pons curve token sale with price-impact warning and exact input. |
| `pons_claim` | via `run_tool` | Prepare claim of eligible Pons launch creator fees. |
| `pons_holders` | via `run_tool` | Read who holds this token: the Pons holder directory and holder balances, page by page; requires its token address. |
| `pons_holdings` | via `run_tool` | Read every Pons coin a wallet holds, found without a token address and re-read on chain; index USD values are estimates, not quotes. |
| `pons_trending` | via `run_tool` | Read the trending Pons launches from Pons's public index. |
| `pons_analytics` | via `run_tool` | Read Pons protocol totals (overview, burn or buyback) from its public index; unaudited. |
| `pons_activity` | via `run_tool` | Read a wallet's Pons activity history, page by page. |
| `pons_launch_info` | via `run_tool` | Read a Pons launch's creator metadata, curve capacity, snipe tax, pending fee-recipient change and buyback vest schedule. |
| `pons_trades` | via `run_tool` | Read a Pons launch's curve buys and sells from its on-chain events in a bounded block window; graduated-pool swaps are not listed. |
| `pons_profile` | via `run_tool` | Read a wallet's Pons profile text (untrusted) and the launches it created. |

### 12. Orbio (23)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `orbio_buy_credit` | yes | Prepare purchase of Orbio credits. |
| `orbio_buy_held_credit` | via `run_tool` | Prepare buying held Orbio credit with USDG, bounded by a minimum credit out and a fill limit. |
| `orbio_activate_credit` | via `run_tool` | Prepare activating held Orbio credit for yourself or a named beneficiary. |
| `orbio_transfer_credit` | via `run_tool` | Prepare transferring held Orbio credit to another address. |
| `orbio_credit_status` | yes | Read wallet CREDIT and activation receipts without a signature. Activated account balance stays unverified until you authenticate with orbio_account; status reuses an existing local credential. |
| `orbio_tx_status` | via `run_tool` | Read the status of an Orbio-related transaction on Robinhood Chain or Ethereum. |
| `orbio_catalog` | via `run_tool` | Browse the Orbio catalog of models, tools or infrastructure with optional search and output-modality filters. |
| `orbio_staking_status` | via `run_tool` | Read your ORBIO staking balance, pending rewards and staking parameters. |
| `orbio_stake` | via `run_tool` | Prepare staking ORBIO. |
| `orbio_unstake` | via `run_tool` | Prepare unstaking ORBIO. |
| `orbio_claim_staking` | via `run_tool` | Prepare claiming ORBIO staking rewards. |
| `orbio_agent_status` | via `run_tool` | Read Orbio agent launches, analytics or price charts, for one agent or the agents you own. |
| `orbio_agent_launch` | via `run_tool` | Prepare launching an Orbio agent token with its name, symbol and optional profile details. |
| `orbio_agent_harvest` | via `run_tool` | Prepare harvesting fees for the listed Orbio agents. |
| `orbio_agent_claim_credit` | via `run_tool` | Prepare claiming an Orbio agent's credit, optionally activating it. |
| `orbio_agent_withdraw_principal` | via `run_tool` | Prepare withdrawing ORBIO principal from an Orbio agent. |
| `orbio_agent_set_wallet` | via `run_tool` | Prepare setting the payout wallet of an Orbio agent. |
| `orbio_account` | via `run_tool` | Run locally: derive this wallet's Orbio API key from a signed key message (a person approves the signature) and read its balance and limits; the key is never shown or sent to the Oak server. |
| `orbio_rotate_key` | via `run_tool` | Run locally: rotate this wallet's Orbio API key to a higher epoch (a person approves the signature); the first request with it retires every lower epoch. |
| `orbio_chat` | via `run_tool` | Run an Orbio model chat locally, paid from this wallet's activated Orbio balance within a CREDIT ceiling you set; a person confirms the spend. |
| `orbio_call_tool` | via `run_tool` | Run a metered Orbio tool locally within a CREDIT ceiling; some tools act outside Orbio, for example by publishing or deleting, and a person confirms the call unless it is a known read with a zero ceiling. |
| `orbio_infra_call` | via `run_tool` | Run an Orbio infra call locally; requires an activated account, even for reads. Changes need an idempotency key, cost ceiling and human confirmation. |
| `orbio_swap_quote` | via `run_tool` | Read an Orbio swap quote for ORBIO, ETH or USDG locally; it only quotes, and nothing is built or signed beyond the wallet-key message. |

### 13. HoodLock (24)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `hoodlock_lock` | yes | Prepare a supported token or liquidity-position lock. |
| `hoodlock_burn` | via `run_tool` | Prepare a supported token burn. |
| `hoodlock_list_locks` | yes | Read supported wallet token/liquidity locks. |
| `hoodlock_airdrop_create` | via `run_tool` | Prepare an airdrop and return its recipient/proof data. |
| `hoodlock_airdrop_claim` | via `run_tool` | Discover eligible airdrops when id is omitted, or prepare a proof-based claim. |
| `hoodlock_vesting_create` | via `run_tool` | Prepare a token vesting schedule (start, cliff, end) for one beneficiary or a list of entries. |
| `hoodlock_vesting_status` | via `run_tool` | Read HoodLock vesting schedules by id, or by account and role. |
| `hoodlock_vesting_claim` | via `run_tool` | Prepare claiming the vested amount of a HoodLock vesting schedule. |
| `hoodlock_vesting_transfer` | via `run_tool` | Prepare transferring a HoodLock vesting schedule to a new beneficiary. |
| `hoodlock_withdraw` | yes | Prepare withdrawing an unlocked token, Uniswap v2, v3 or v4 lock. |
| `hoodlock_extend` | via `run_tool` | Prepare extending a lock's unlock time; it can only be moved later. |
| `hoodlock_transfer_lock` | via `run_tool` | Prepare transferring ownership of a HoodLock lock. |
| `hoodlock_set_fee_recipient` | via `run_tool` | Prepare changing who receives fees from a locked liquidity position. |
| `hoodlock_collect` | via `run_tool` | Prepare collecting fees from one or more locked liquidity positions. |
| `hoodlock_airdrop_sweep` | via `run_tool` | Prepare sweeping the unclaimed remainder of an airdrop back to its creator after it ends. |
| `hoodlock_record` | via `run_tool` | Read the record of one HoodLock lock, burn, vesting or airdrop. |
| `hoodlock_read` | via `run_tool` | Run an allow-listed read-only method on a HoodLock contract (locker, burner, vesting, airdrop or liquidity locker). |
| `hoodlock_recover` | via `run_tool` | Prepare recovering owed ETH from a HoodLock contract through an allow-listed method. |
| `hoodlock_admin` | via `run_tool` | Prepare an allow-listed HoodLock administrator action, usable only by the contract admin. |
| `hoodlock_public` | via `run_tool` | Read public HoodLock data such as LP locks, airdrop lists, featured tiers, buyback status and referral availability. |
| `hoodlock_buyback` | via `run_tool` | Prepare the pinned HoodLock buyback vault execute call, with no caller-supplied amount, recipient or calldata. |
| `hoodlock_feature_buy` | via `run_tool` | Buy a HoodLock featured listing with an exact quoted ETH payment and a separate publication claim; human confirmation required. |
| `hoodlock_feature_claim` | via `run_tool` | Reconcile an already-paid HoodLock featured listing without paying again; human confirmation required. |
| `hoodlock_referral_register` | via `run_tool` | Register a HoodLock referral code through a local wallet message and ephemeral session; human confirmation required. |

### 14. Merkl (13)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `merkl_rewards` | yes | Read claimable rewards; empty means no currently published claimable rewards, possibly none earned or not yet settled/indexed (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_claim` | yes | Claim rewards on Merkl (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_opportunities` | via `run_tool` | State oak.lpWarning first before preparing any liquidity addition. Browse Merkl reward opportunities by protocol, name or explorer address, with campaign conditions and indicative rates (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_campaigns` | via `run_tool` | Read Merkl campaign rules, optionally for one opportunity, creator or reward token symbol (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_earning_status` | via `run_tool` | Read this wallet's Merkl reward status: active opportunities, per-opportunity breakdowns, totals or claim history; API data can lag (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_claim_config` | via `run_tool` | Read this wallet's saved Merkl claim recipients and whether a named operator may claim for it. |
| `merkl_set_operator` | via `run_tool` | Prepare allowing or revoking a named operator to claim Merkl rewards for this wallet; the zero address allows anyone to claim, and payouts still follow your recipients. |
| `merkl_set_recipient` | via `run_tool` | Prepare sending this wallet's future Merkl claims to a named recipient, for all tokens or one; the zero address restores claiming to yourself. |
| `merkl_claim_to` | via `run_tool` | Prepare claiming this wallet's verified Merkl rewards to a named recipient for this claim only, with optional recipient callback data (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_claim_for` | via `run_tool` | Prepare claiming another user's verified Merkl rewards on their behalf: you pay gas and the rewards go to that user's own recipients (Powered by Merkl — https://app.merkl.xyz). |
| `merkl_distributor_status` | via `run_tool` | Read the Merkl Distributor's current root, dispute terms and timing, and this wallet's roles on it. |
| `merkl_dispute` | via `run_tool` | Prepare disputing the Merkl Distributor's current tree with an exact collateral approval; the collateral stays locked and is forfeited if the dispute is rejected. |
| `merkl_distributor_admin` | via `run_tool` | Prepare a Merkl Distributor governor, guardian or updater operation, such as updating or revoking the tree, trusting an operator or recovering tokens to a named recipient; it affects all claimants. |

### 15. Relay (25)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `relay_bridge_out` | yes | Bridge ETH or ERC-20 out; checks return RPC/tracing on server and add-on (OAK_RPC_URL_<chainId>). Default slippage 500 bps; review the minimum. |
| `relay_status` | yes | Read a known Relay requestId status without an API key; requestId is required. Optional destination receipt checks need its chain RPC. |
| `relay_bridge_in` | yes | Prepare an inbound Relay bridge route to Robinhood Chain. A fresh wallet may bridge ETH or USDG to itself before it has an identity or subscription; every other shape needs both. |
| `relay_quote` | via `run_tool` | Read a Relay estimate; requires operator-configured Relay API credentials because quote/v2 requires authentication since October 2, 2026. Nothing is signed. |
| `relay_chains` | via `run_tool` | Read Relay chains and supported currency metadata without an API key. |
| `relay_chain_health` | via `run_tool` | Read Relay chain service health; chainId is required. |
| `relay_token_details` | via `run_tool` | Read Relay token metadata and market analytics. |
| `relay_token_chart` | via `run_tool` | Read historical Relay token market charts. |
| `relay_trending` | via `run_tool` | List Relay trending tokens. Ranking is not an endorsement. |
| `relay_exchange_rates` | via `run_tool` | Read Relay reference exchange rates without freshness guarantees. |
| `relay_protocol_execution` | via `run_tool` | Read Relay oracle execution status; this is not destination fill verification. |
| `relay_currencies` | via `run_tool` | Search Relay currencies and deposit-address eligibility. No funds are moved. |
| `relay_token_price` | via `run_tool` | Read a Relay USD token price; this endpoint supplies no freshness timestamp. |
| `relay_currency_classifications` | via `run_tool` | Read Relay major and stable token fee categories. |
| `relay_liquidity` | via `run_tool` | Read indicative Relay solver liquidity by chain. |
| `relay_swap_sources` | via `run_tool` | List Relay swap venues available for routing filters. |
| `relay_requests` | via `run_tool` | Page this wallet’s Relay request history, including pending and child requests; needs operator-configured Relay API credentials. |
| `relay_app_fee_balance` | via `run_tool` | Read this wallet’s off-chain Relay app fee credits. |
| `relay_app_fee_claims` | via `run_tool` | Page this wallet’s previous Relay fee claims. |
| `relay_balance_events` | via `run_tool` | Page this wallet’s Relay fee and sponsorship balance events; needs operator-configured Relay API credentials. |
| `relay_deposit_address` | via `run_tool` | Monitor a Relay deposit address and its deposits, sweeps, fills and refunds. |
| `relay_recovery_balances` | via `run_tool` | Read this wallet’s credited Relay recovery balances; this does not attest deposits. |
| `relay_withdrawal_status` | via `run_tool` | Read a Relay programmatic withdrawal job status; verify its chain receipt separately. |
| `relay_vault_status` | via `run_tool` | Read legacy Relay vault shares and exit liquidity; needs OAK_RPC_URL_1 or OAK_RPC_URL_42161 for that chain. New deposits are unsupported. |
| `relay_vault_withdraw` | via `run_tool` | Preview a legacy Relay vault exit to this wallet on Ethereum or Arbitrum, in WETH or native ETH. |

### 16. Lighter (1)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `lighter_funding` | yes | Read Lighter funding data without submitting trades. |

### 17. ERC-8004 (19)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `erc8004_register` | via `run_tool` | Prepare ERC-8004 identity registration. |
| `erc8004_update` | via `run_tool` | Prepare an update to an owned ERC-8004 agent registration. |
| `erc8004_identity` | yes | Read ERC-8004 agent identity and ownership. |
| `erc8004_wallet_proof` | via `run_tool` | Read the typed-data proof a new wallet signs to become an agent's wallet; nothing is signed or sent. |
| `erc8004_set_wallet` | via `run_tool` | Prepare setting an ERC-8004 agent's wallet using the new wallet's signed proof. |
| `erc8004_unset_wallet` | via `run_tool` | Prepare clearing an ERC-8004 agent's wallet. |
| `erc8004_transfer` | via `run_tool` | Prepare transferring an ERC-8004 agent identity NFT to another address. |
| `erc8004_approve` | via `run_tool` | Prepare approving or clearing the approved operator for one agent identity NFT. |
| `erc8004_set_operator` | via `run_tool` | Prepare approving or revoking an operator for all of your agent identity NFTs. |
| `erc8004_set_metadata` | via `run_tool` | Prepare setting a metadata key on an ERC-8004 agent, from a value or text. |
| `erc8004_owned` | via `run_tool` | List the ERC-8004 agent identities owned by an address. |
| `erc8004_give_feedback` | via `run_tool` | Prepare public reputation feedback for an ERC-8004 agent. |
| `erc8004_revoke_feedback` | via `run_tool` | Prepare revoking feedback you gave an ERC-8004 agent. |
| `erc8004_append_response` | via `run_tool` | Prepare appending a response to feedback given to an agent. |
| `erc8004_reputation` | via `run_tool` | Read agent reputation feedback and summary; summary should name trusted reviewers in clients. Discover feedback first and let the user select trusted clients; do not treat all clients as trusted. |
| `erc8004_validation_request` | via `run_tool` | Prepare asking a validator to validate an ERC-8004 agent. |
| `erc8004_validation_response` | via `run_tool` | Prepare a validator's response to a validation request. |
| `erc8004_validation` | via `run_tool` | Read ERC-8004 validation requests and responses by request hash, agent or validator. |
| `erc8004_verify_domain` | via `run_tool` | Read whether an agent's registered endpoint domain publishes a matching agent-registration file. |

### 18. hood.ag (27)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `hoodag_register` | yes | Prepare hood.ag name registration. |
| `hoodag_resolve` | yes | Resolve a hood.ag name. |
| `hoodag_name_info` | via `run_tool` | Read hood.ag name registration information. |
| `hoodag_renew` | via `run_tool` | Prepare renewing a .hood name for a stated duration, paid in USDG or ETH; anyone may fund a renewal and ownership does not change. |
| `hoodag_text` | via `run_tool` | Read a text record (such as avatar or url) of a .hood name; the content is untrusted. |
| `hoodag_set_address` | via `run_tool` | Prepare pointing a .hood name at a named wallet address; only the name's owner can do it. |
| `hoodag_set_text` | via `run_tool` | Prepare setting a public text record on a .hood name; an empty value clears it. |
| `hoodag_contenthash` | via `run_tool` | Read a .hood name's encoded contenthash; no content is fetched. |
| `hoodag_set_contenthash` | via `run_tool` | Prepare setting a .hood name's contenthash from encoded bytes, where 0x clears it; nothing is uploaded. |
| `hoodag_set_primary` | via `run_tool` | Prepare making a .hood name this wallet's primary reverse name; the wallet must own it and it must resolve back to the wallet. |
| `hoodag_clear_primary` | via `run_tool` | Prepare clearing this wallet's primary reverse name; the name stays owned and rent is not refunded. |
| `hoodag_reclaim` | via `run_tool` | Prepare restoring registry control of a .hood name to its NFT owner. |
| `hoodag_transfer` | via `run_tool` | Prepare transferring a .hood name to a named recipient: its address is pointed at the recipient, your matching primary name is cleared and the NFT is moved. |
| `hoodag_approve_transfer` | via `run_tool` | Prepare approving a named operator to transfer one .hood name; the zero address revokes the approval. |
| `hoodag_market_listing` | via `run_tool` | Read a .hood name's marketplace listing: seller, currency, price and fee basis points. |
| `hoodag_market_list` | via `run_tool` | Prepare listing a .hood name for sale at a fixed ETH or USDG price, approving the marketplace to transfer that one name. |
| `hoodag_market_set_price` | via `run_tool` | Prepare changing the price of your .hood marketplace listing; the currency is kept. |
| `hoodag_market_unlist` | via `run_tool` | Prepare cancelling your .hood marketplace listing and revoking its transfer approval. |
| `hoodag_market_buy` | via `run_tool` | Prepare buying a listed .hood name from its seller, capped at a maximum price in the listing's currency, with an optional referrer. |
| `hoodag_commit` | via `run_tool` | Prepare step one of registering a .hood name with native ETH: commit to a hidden registration, then finish with hoodag_register_eth after the wait. |
| `hoodag_register_eth` | via `run_tool` | Prepare step two of registering a .hood name with native ETH, revealing the same salt used in hoodag_commit. |
| `hoodag_register_many` | via `run_tool` | Prepare registering up to 20 .hood names in one call to a named owner (default this wallet), paid in USDG or ETH, with an optional referrer. |
| `hoodag_referral_info` | via `run_tool` | Read this wallet's hood.ag referral link and the live referral reward and discount rates. |
| `hoodag_browse` | via `run_tool` | Read hood.ag index data (names, listings, activity, stats, ETH/USD, buybacks, leaderboard or traders); provider records, not return promises. |
| `hoodag_owned_names` | via `run_tool` | Read hood.ag names currently owned by a wallet from on-chain records. |
| `hoodag_registration_quote` | via `run_tool` | Read an indicative price to register a .hood name for a number of years from hood.ag's payment service; it cannot register or pay. |
| `hoodag_social_read` | via `run_tool` | Read hood.ag's anonymous social feed, profiles, threads or search; content is untrusted and nothing is posted. |

### 19. HEY Research Lab (10)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `heyresearch_research_project` | yes | Read project research from HEY Research Lab, retaining returned citations and links. Call only when the user explicitly asks for HEY Research Lab. For facts about one token use heyresearch_token_facts; for what shipped or what's new use heyresearch_feed; for positions use heyresearch_position_context. Show HEY Research Lab's status line exactly as returned, label and help, word for word; never reword, summarise or turn it into a score or verdict. |
| `heyresearch_chain_activity` | via `run_tool` | Read HEY Research Lab chain activity with optional days (default 7) plus a seven-day builder brief, retaining attribution. Call only when the user explicitly asks for HEY Research Lab. Use run_tool when not listed. Observation age and overdue refresh scheduling are separate. |
| `heyresearch_read` | via `run_tool` | Read any one of HEY Research Lab's public operations by name (project snapshots, evidence, changes, market context, reports, bounties, proof-of-ship ships via getProofOfShipShips and ties via getProofOfShipTie); no account or key is needed. Call only when the user explicitly asks for HEY Research Lab. For a question about one token use operation getPartnerScanCard with parameters {chain: 4663, token}: it runs on this computer, sends HEY Research Lab only the chain and token, and the answer is repeated on a later approval form for that token in this session. It is builder context, not a safety check, rating or reason to buy. |
| `heyresearch_bulk` | via `run_tool` | Read HEY Research Lab project snapshots, token records or scan cards in bulk (up to 10 projects or 30 tokens); it uses the Oak server's operator-configured HEY Research Lab key, never one you pass. Call only when the user explicitly asks for HEY Research Lab. |
| `heyresearch_validate_receipt` | via `run_tool` | Read HEY Research Lab's stateless validation of a research receipt you submit (up to 64 KiB, sent to HEY Research Lab; nothing is stored or signed). Call only when the user explicitly asks for HEY Research Lab. |
| `heyresearch_token_facts` | yes | Only when the user asks for HEY Research Lab: facts about one token on Robinhood Chain (4663), with HEY Research Lab's own words, dated and linked, kept in a block apart from Oak's reads of the same token (Pons status, address counts, launch record; unread figures say not read). Runs on this computer; HEY Research Lab receives the token address and its project slug, never your wallet or amounts. Show HEY Research Lab's status line exactly as returned, label and help, word for word; never reword, summarise or turn it into a score or verdict. |
| `heyresearch_feed` | yes | Only when the user asks for HEY Research Lab: its builder updates, newest first, word for word with dates and source links. mode browse lists recent updates; mode updates checks the tokens you follow. A complete updates check saves its last-checked time to the follow file on this computer, so this read changes that one local file and nothing else; nothing is sent to anyone but HEY Research Lab, and nothing runs in the background. Pass the continuation back to finish a long check. Show HEY Research Lab's status line exactly as returned, label and help, word for word; never reword, summarise or turn it into a score or verdict. |
| `heyresearch_follow` | yes | Only when the user asks for HEY Research Lab: add a token and its HEY Research Lab project slug to your follow list, a local file on this computer (up to 20 tokens). Contacts no one, signs nothing and needs no subscription. The pairing is yours and stays unverified until you ask for a feed check. |
| `heyresearch_unfollow` | via `run_tool` | Only when the user asks for HEY Research Lab: remove a token from your follow list, a local file on this computer. Contacts no one, signs nothing and needs no subscription. |
| `heyresearch_position_context` | yes | Only when the user asks for HEY Research Lab: for positions you select, add HEY Research Lab context for the token contract or project slug you name for each. Oak reads your positions as it always does; HEY Research Lab receives only the slugs or contracts you chose, never your wallet, amounts or position IDs, and the two are joined on this computer. HEY Research Lab's words stay in their own block apart from Oak's facts. Show HEY Research Lab's status line exactly as returned, label and help, word for word; never reword, summarise or turn it into a score or verdict. |

### 20. Priors (201)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `priors_lend` | yes | Prepare lending assets into Priors. |
| `priors_withdraw` | yes | Prepare withdrawal from Priors lending. |
| `priors_borrow` | yes | Prepare a Priors borrowing operation. |
| `priors_repay` | yes | Prepare repayment of Priors debt. |
| `priors_status` | yes | Read Priors lending/borrowing account state, the agent's on-chain score, line, invite bond and next step. |
| `priors_starter_line` | via `run_tool` | Needs a 5 USDG bond locked about four days; invites are not guaranteed and the score can lag. Open Priors' 5 USDG starter line for an owned agent with no Priors record, with each step confirmed. |
| `priors_close_line` | via `run_tool` | Prepare closing an agent's Priors line (no loan open), the step before its invite bond can come back. |
| `priors_release_bond` | via `run_tool` | Prepare returning a releasable Priors invite bond to the wallet that posted it. |
| `priors_set_delegate` | via `run_tool` | Prepare setting the delegate that controls an agent's borrowing and repayment; clearing it uses the zero address. |
| `priors_root_enroll` | via `run_tool` | Prepare enrolling USDG as a sponsor root's stake, as pool shares locked behind that root. |
| `priors_root_add_stake` | via `run_tool` | Prepare adding USDG stake to a sponsor root; anyone may add, only the root owner can withdraw. |
| `priors_root_unlock` | via `run_tool` | Prepare withdrawing root pool shares to your wallet, subject to delegated backing and fee locks. |
| `priors_root_retire` | via `run_tool` | Prepare retiring a sponsor root with no remaining stake or delegated lines. |
| `priors_root_vouch` | via `run_tool` | Prepare adding undrawn USDG backing from a sponsor to a sponsored agent's line. |
| `priors_root_unvouch` | via `run_tool` | Prepare recalling undrawn backing from a sponsored line; outstanding debt stays backed. |
| `priors_root_freeze` | via `run_tool` | Prepare freezing or unfreezing a sponsored agent's line. |
| `priors_root_set_premium` | via `run_tool` | Prepare setting the sponsor premium on future loans, within the owner-consented cap. |
| `priors_root_claim_fees` | via `run_tool` | Prepare claiming a sponsor's USDG fees to your wallet. |
| `priors_root_set_hook` | via `run_tool` | Prepare changing a root's lending-policy hook, which takes effect after an on-chain delay. |
| `priors_root_apply_hook` | via `run_tool` | Prepare applying a previously scheduled root hook after its delay. |
| `priors_mark_default` | via `run_tool` | Prepare marking a past-grace unpaid loan as defaulted; irreversible and burns sponsor backing. |
| `priors_import_history` | via `run_tool` | Prepare importing an agent's v1 Priors record, including defaults; it never imports unbacked capacity. |
| `priors_fund_reserve` | via `run_tool` | Prepare donating USDG to the Priors pool reserve; no redeemable shares are issued. |
| `priors_root_shares` | via `run_tool` | Read a sponsor root's pool shares. |
| `priors_root_fee_locked` | via `run_tool` | Read the sponsor fees locked against a root's withdrawals. |
| `priors_root_fees_owed` | via `run_tool` | Read the sponsor fees a root has accrued. |
| `priors_root_backing` | via `run_tool` | Read a root's total backing. |
| `priors_root_free_backing` | via `run_tool` | Read a root's backing not yet committed to lines. |
| `priors_pool_parameters` | via `run_tool` | Read the Priors pool's loan size, term, grace, fee, utilization and keeper-bounty parameters. |
| `priors_bond_deposit` | via `run_tool` | Prepare depositing an agent's Priors treasury bond. |
| `priors_bond_release` | via `run_tool` | Prepare releasing a Priors bond to its original depositor once its conditions are met. |
| `priors_bond_slash` | via `run_tool` | Prepare slashing a defaulted agent's bond to the configured beneficiary; irreversible. |
| `priors_bond_status` | via `run_tool` | Read an agent's Priors bond depositor, deposit time and amount. |
| `priors_bond_releasable` | via `run_tool` | Read whether an agent's Priors bond can be released now. |
| `priors_bond_release_at` | via `run_tool` | Read when an unused Priors bond becomes releasable. |
| `priors_treasury_move` | via `run_tool` | Prepare moving a former Priors Treasury V4 line to V5 (no loan open), with the owner's signed consent. |
| `priors_treasury_raise` | via `run_tool` | Prepare raising an eligible agent's Priors treasury line under its current rules; no unbacked credit. |
| `priors_treasury_reclaim` | via `run_tool` | Prepare reclaiming an idle Priors treasury line, which ends its borrowing access. |
| `priors_treasury_first_line` | via `run_tool` | Prepare redeeming an already-issued Priors Treasury V5 first-line invite, with the owner's signed pool consent. |
| `priors_treasury_raise_room` | via `run_tool` | Read how much Priors treasury raise room is available. |
| `priors_treasury_first_lined` | via `run_tool` | Read whether an agent has already received a first treasury line. |
| `priors_treasury_eligible_raise` | via `run_tool` | Read whether an agent is eligible for a treasury line raise. |
| `priors_treasury_room` | via `run_tool` | Read the Priors treasury's remaining room for the current epoch. |
| `priors_treasury_rules` | via `run_tool` | Read the Priors treasury rules: reserve, first and second line sizes, epoch cap, seasoning and score minimums. |
| `priors_stock_open` | via `run_tool` | Prepare opening a stock-collateral line for an agent by depositing a supported stock token, with the owner's signed consent. |
| `priors_stock_add` | via `run_tool` | Prepare adding stock-token collateral to an open line; depositor only. |
| `priors_stock_close` | via `run_tool` | Prepare closing or freezing a stock-collateral line; collateral is returned after the last loan. |
| `priors_stock_expire` | via `run_tool` | Prepare expiring an idle stock-collateral line under on-chain idle rules. |
| `priors_stock_reconcile` | via `run_tool` | Prepare reconciling a stock line's collateral with the pool's loans. |
| `priors_stock_settle` | via `run_tool` | Prepare settling stock collateral after a default or missed hook; collateral may be seized. |
| `priors_stock_record_feed` | via `run_tool` | Prepare recording the public oracle price tape for a stock feed. |
| `priors_stock_reclaim` | via `run_tool` | Prepare reclaiming a written-off stock position once it is no longer backed. |
| `priors_stock_state` | via `run_tool` | Read an agent's stock-collateral position. |
| `priors_stock_borrow_room` | via `run_tool` | Read how much an agent can still borrow against its stock collateral. |
| `priors_stock_asset_state` | via `run_tool` | Read a stock token's oracle feed, loan-to-value and line cap. |
| `priors_stock_lending_status` | via `run_tool` | Read whether lending against a stock token is currently open. |
| `priors_stock_value` | via `run_tool` | Read the USD value of an amount of a stock token. |
| `priors_stock_ltv` | via `run_tool` | Read an agent's loan-to-value against a stock token. |
| `priors_backing_open` | via `run_tool` | Prepare opening an agent's owner-staked PRIORS backing book, with the owner's signed consent. |
| `priors_backing_open_with_usdg` | via `run_tool` | Prepare opening backing by swapping USDG into PRIORS first, with a minimum-out bound and a deadline. |
| `priors_backing_add` | via `run_tool` | Prepare adding PRIORS stake to an open backing book. |
| `priors_backing_add_with_usdg` | via `run_tool` | Prepare adding backing by swapping USDG into PRIORS first, with a minimum-out bound and a deadline. |
| `priors_backing_leave` | via `run_tool` | Prepare starting an exit of backing stake in the chosen exit mode; the stake stays at risk until released. |
| `priors_backing_close` | via `run_tool` | Prepare closing a backing book in the chosen exit mode. |
| `priors_backing_refresh` | via `run_tool` | Prepare a refresh of an agent's backing book against current pool, owner, record, tier and backing rules; no payout is promised. |
| `priors_backing_promote` | via `run_tool` | Prepare a promote call on an agent's backing book, reconciling it against current tier and backing rules; no payout is promised. |
| `priors_backing_expire` | via `run_tool` | Prepare an expire call on an agent's backing book under current rules; no payout is promised. |
| `priors_backing_sync` | via `run_tool` | Prepare a sync of an agent's backing book with current pool and record state; no payout is promised. |
| `priors_backing_poke_fees` | via `run_tool` | Prepare a fee poke on an agent's backing book, reconciling its fee accounting; no payout is promised. |
| `priors_backing_record_repay` | via `run_tool` | Prepare recording an agent's loan repayment in its backing book; no payout is promised. |
| `priors_backing_note_delegate` | via `run_tool` | Prepare recording an agent's delegate change in its backing book; no payout is promised. |
| `priors_backing_set_auto_add` | via `run_tool` | Prepare switching a backing book's automatic re-adding of rewards on or off; auto-add can compound rewards into stake at risk. |
| `priors_backing_set_protocol_backing` | via `run_tool` | Prepare allowing or disallowing protocol backing on a book. |
| `priors_backing_set_others_backing` | via `run_tool` | Prepare allowing or disallowing backing from other wallets on a book. |
| `priors_backing_reconsent` | via `run_tool` | Prepare renewing an owner's consent to a backing book's premium cap. |
| `priors_backing_release` | via `run_tool` | Prepare releasing a day bucket of backing stake as PRIORS, or through a guarded sale with a minimum USDG out. |
| `priors_backing_release_for` | via `run_tool` | Prepare returning a holder's eligible PRIORS to that holder; proceeds are never redirected. |
| `priors_backing_finish_close` | via `run_tool` | Prepare finishing an eligible backing-generation close. |
| `priors_backing_claim_settled` | via `run_tool` | Prepare paying a settled generation's stake to the named holder, after any default burn. |
| `priors_backing_claim_record` | via `run_tool` | Prepare paying a settled day record to its holder, after any default burn. |
| `priors_backing_queue_exit` | via `run_tool` | Prepare queueing a holder's ready USDG-mode stake for exit; a queue entry is not a fill. |
| `priors_backing_settle` | via `run_tool` | Prepare reconciling a backing generation with a pool loan or default. |
| `priors_backing_record_loan` | via `run_tool` | Prepare recording a pool loan in the backing book. |
| `priors_backing_record_default` | via `run_tool` | Prepare reconciling a pool default and its stake burn in the backing book. |
| `priors_backing_collect` | via `run_tool` | Prepare collecting your fees for explicitly selected agents and generations. |
| `priors_backing_fund` | via `run_tool` | Prepare donating USDG to root backing; no withdrawable claim is issued. |
| `priors_backing_book` | via `run_tool` | Read a backing generation's full book state. |
| `priors_backing_generation` | via `run_tool` | Read an agent's latest backing generation. |
| `priors_backing_line` | via `run_tool` | Read the credit line a backing book supports. |
| `priors_backing_quote` | via `run_tool` | Read the stake needed to open or add backing and the line it would give. |
| `priors_backing_position` | via `run_tool` | Read a holder's backing position in a generation and layer. |
| `priors_backing_record` | via `run_tool` | Read a holder's backing record for a generation, layer and day. |
| `priors_backing_bucket` | via `run_tool` | Read a leaving-stake bucket's release state. |
| `priors_backing_settings` | via `run_tool` | Read backing-wide settings: open backing, premium cap, swap limit, room and vouch cap. |
| `priors_backing_reopen_at` | via `run_tool` | Read when an agent's backing can reopen. |
| `priors_backing_sync_prices` | via `run_tool` | Prepare updating the backing contract's global price observations. |
| `priors_backing_exit_service_open` | via `run_tool` | Read whether the backing exit service is open. |
| `priors_backing_usdg_path` | via `run_tool` | Read whether the USDG entry path is open for a USDG amount. |
| `priors_backing_entry_rule` | via `run_tool` | Read the minimum loans and days an agent needs before backing entry. |
| `priors_backing_target_premium` | via `run_tool` | Read an agent's target premium in basis points. |
| `priors_backing_price_cache` | via `run_tool` | Read the backing contract's cached price observations. |
| `priors_backing_pending_bucket` | via `run_tool` | Read a pending backing deposit bucket. |
| `priors_backing_exit_head` | via `run_tool` | Read the head of the backing exit queue. |
| `priors_backing_exit_entry` | via `run_tool` | Read one backing exit queue entry. |
| `priors_backing_flush` | via `run_tool` | Prepare reconciling backing fees and buffers; no payout to the caller is promised. |
| `priors_backing_claimable` | via `run_tool` | Read the backing amount an address can claim. |
| `priors_autopay_hold` | via `run_tool` | Prepare holding or resuming future autopay attempts for your wallet; allowances remain until revoked. |
| `priors_autopay_max_cap` | via `run_tool` | Read the maximum autopay cap. |
| `priors_autopay_window` | via `run_tool` | Read the autopay repayment window. |
| `priors_autopay_paused_until` | via `run_tool` | Read until when autopay is paused. |
| `priors_autopay_plan` | via `run_tool` | Read a wallet's autopay plan for an agent. |
| `priors_autopay_check` | via `run_tool` | Read whether autopay can cover a loan now, and from which funds. |
| `priors_autopay_epoch` | via `run_tool` | Read an agent's autopay epoch and whether it is stale. |
| `priors_autopay_held` | via `run_tool` | Read whether a wallet's autopay is held. |
| `priors_savings_deposit` | via `run_tool` | Prepare depositing your USDG into Priors' default external Morpho savings vault. |
| `priors_savings_withdraw` | via `run_tool` | Prepare withdrawing an exact USDG amount from your savings; fails if liquidity is short. |
| `priors_savings_redeem` | via `run_tool` | Prepare redeeming an exact number of your savings shares. |
| `priors_savings_balance` | via `run_tool` | Read a wallet's savings share balance. |
| `priors_savings_value` | via `run_tool` | Read the USDG value of a number of savings shares. |
| `priors_market_v2_listing` | via `run_tool` | Read an agent identity's current listing on the Priors market (v2). |
| `priors_market_v2_record_hash` | via `run_tool` | Read the record hash a v2 market purchase must pin for an agent. |
| `priors_market_v2_list` | via `run_tool` | Prepare listing an agent identity NFT, with its record and any treasury line, for sale on the v2 market. |
| `priors_market_v2_cancel` | via `run_tool` | Prepare cancelling a v2 market listing. |
| `priors_market_v2_buy` | via `run_tool` | Prepare buying a listed agent identity on the v2 market with a price cap and pinned record hash. |
| `priors_market_v1_listing` | via `run_tool` | Read an agent identity's current listing on the original (v1) Priors market. |
| `priors_market_v1_record_hash` | via `run_tool` | Read the record hash a v1 market purchase must pin for an agent. |
| `priors_market_v1_list` | via `run_tool` | Prepare listing an agent identity for sale on the v1 market. |
| `priors_market_v1_cancel` | via `run_tool` | Prepare cancelling a v1 market listing. |
| `priors_market_v1_buy` | via `run_tool` | Prepare buying a listed agent identity on the v1 market with a price cap and pinned record hash. |
| `priors_market_bid` | via `run_tool` | Prepare a standing bid for one agent identity; another owner can fill it later without a new click. |
| `priors_market_bid_any` | via `run_tool` | Prepare a standing bid for several identities committed by a Merkle root, with a shared USDG reserve budget. |
| `priors_market_cancel_bid` | via `run_tool` | Prepare cancelling a bid; the shared USDG allowance is unchanged. |
| `priors_market_accept_bid` | via `run_tool` | Prepare selling one agent identity into a valid bid, with a minimum net proceeds bound. |
| `priors_market_bid_state` | via `run_tool` | Read a market bid's maker, price, expiry and requirements. |
| `priors_market_builder` | via `run_tool` | Read an agent's builder address and revenue share. |
| `priors_market_set_builder` | via `run_tool` | Prepare assigning a builder revenue share on future sales (owner only, capped at 500 bps). |
| `priors_market_change_builder` | via `run_tool` | Prepare lowering or redirecting a builder share (current builder only). |
| `priors_market_sale_split` | via `run_tool` | Read how a sale price splits between fee, builder share and seller net. |
| `priors_legacy_v3_close` | via `run_tool` | Prepare closing an existing legacy v3 seat; stake returns to the original staker after the final loan. |
| `priors_legacy_v3_withdraw_offer` | via `run_tool` | Prepare withdrawing a legacy v3 offer. |
| `priors_legacy_v3_expire` | via `run_tool` | Prepare expiring an idle legacy v3 seat. |
| `priors_legacy_v3_settle` | via `run_tool` | Prepare settling a legacy v3 seat against a loan. |
| `priors_legacy_v3_claim` | via `run_tool` | Prepare claiming legacy v3 proceeds. |
| `priors_legacy_v3_seat` | via `run_tool` | Read an agent's legacy v3 seat. |
| `priors_legacy_v3_pending_fees` | via `run_tool` | Read pending fees on a legacy v3 seat. |
| `priors_legacy_v3_fees` | via `run_tool` | Read legacy v3 fee totals. |
| `priors_legacy_v3_offer` | via `run_tool` | Read an agent's legacy v3 offer. |
| `priors_legacy_v4_close` | via `run_tool` | Prepare closing an existing legacy v4 seat; stake returns to the original staker after the final loan. |
| `priors_legacy_v4_withdraw_offer` | via `run_tool` | Prepare withdrawing a legacy v4 offer. |
| `priors_legacy_v4_expire` | via `run_tool` | Prepare expiring an idle legacy v4 seat. |
| `priors_legacy_v4_settle` | via `run_tool` | Prepare settling a legacy v4 seat against a loan. |
| `priors_legacy_v4_claim` | via `run_tool` | Prepare claiming legacy v4 proceeds. |
| `priors_legacy_v4_seat` | via `run_tool` | Read an agent's legacy v4 seat. |
| `priors_legacy_v4_pending_fees` | via `run_tool` | Read pending fees on a legacy v4 seat. |
| `priors_legacy_v4_fees` | via `run_tool` | Read legacy v4 fee totals. |
| `priors_legacy_v4_offer` | via `run_tool` | Read an agent's legacy v4 offer. |
| `priors_sign_consent` | via `run_tool` | Sign the typed-data consent that lets a sponsor root back an agent, up to a maximum premium. |
| `priors_root_offer` | via `run_tool` | Prepare a sponsor offer of undrawn USDG backing to an agent, with the owner's signed consent. |
| `priors_autopay_on` | via `run_tool` | Prepare turning on autopay for an agent with a per-payment cap, budget and optional savings shares. |
| `priors_autopay_off` | via `run_tool` | Prepare turning off autopay for an agent. |
| `priors_agent_record` | via `run_tool` | Read an agent's Priors record through Priors' hosted MCP. |
| `priors_score_of` | via `run_tool` | Read an agent's Priors score through Priors' hosted MCP. |
| `priors_credit_history` | via `run_tool` | Read an agent's Priors credit history through Priors' hosted MCP. |
| `priors_pool_stats` | via `run_tool` | Read Priors pool statistics through Priors' hosted MCP. |
| `priors_stock_assets` | via `run_tool` | Read the stock assets Priors supports, or one ticker. |
| `priors_stock_position` | via `run_tool` | Read an agent's stock-collateral position through Priors' hosted MCP. |
| `priors_recent_activity` | via `run_tool` | Read recent Priors activity through Priors' hosted MCP. |
| `priors_desk_record` | via `run_tool` | Read a root's desk record through Priors' hosted MCP. |
| `priors_find_services` | via `run_tool` | Search services listed on Priors. |
| `priors_facilitator_info` | via `run_tool` | Read Priors facilitator information. |
| `priors_agents_for_hire` | via `run_tool` | List agents available for hire on Priors. |
| `priors_find_jobs` | via `run_tool` | Search Priors jobs by kind, text, status or agent. |
| `priors_job_brief` | via `run_tool` | Read the brief for one Priors job. |
| `priors_find_sellers` | via `run_tool` | Search sellers on Priors. |
| `priors_agent_page` | via `run_tool` | Read an agent's public Priors page. |
| `priors_find_agents` | via `run_tool` | Search Priors agents by text, takes, record and default filters. |
| `priors_line_options` | via `run_tool` | Read the credit line options available to an agent. |
| `priors_find_line_requests` | via `run_tool` | List open Priors line requests. |
| `priors_line_request` | via `run_tool` | Read one Priors line request. |
| `priors_find_agent_by_x` | via `run_tool` | Find a Priors agent by its linked X handle. |
| `priors_how_to_connect` | via `run_tool` | Read Priors' instructions for connecting an agent. |
| `priors_ethos_status` | via `run_tool` | Read the Ethos claim status that Priors reports. |
| `priors_request_borrow` | via `run_tool` | Read a Priors owner link that asks to borrow USDG for an agent; the link moves no funds. |
| `priors_request_repay` | via `run_tool` | Read a Priors owner link that asks to repay an agent's Priors debt; the link moves no funds. |
| `priors_request_stock` | via `run_tool` | Read a Priors owner link to open a stock-collateral line for an agent; the link moves no funds. |
| `priors_request_backing` | via `run_tool` | Read a Priors owner link that asks for backing on an agent's line; the link moves no funds. |
| `priors_pt_quote` | via `run_tool` | Read a quote to buy or sell PRIORS tokens on the PT route. |
| `priors_pt_position` | via `run_tool` | Read your PRIORS token (PT) position. |
| `priors_pt_buy` | via `run_tool` | Prepare buying PRIORS tokens with a minimum-out bound. |
| `priors_pt_sell` | via `run_tool` | Prepare selling PRIORS tokens with a minimum-out bound. |
| `priors_pt_redeem` | via `run_tool` | Prepare redeeming PRIORS tokens with a minimum-out bound. |
| `priors_savings_liquidity` | via `run_tool` | Read how much of the Priors savings vault can be withdrawn now. |
| `priors_savings_force_withdraw` | via `run_tool` | Prepare a forced savings withdrawal across explicit allocations when the vault lacks liquidity. |
| `priors_stock_quote` | via `run_tool` | Read a quote for swapping a supported stock token. |
| `priors_stock_swap` | via `run_tool` | Prepare swapping a supported stock token, with the quote's bounds. |
| `priors_market_origin` | via `run_tool` | Read the origin (first owner or builder) of agent identities. |
| `priors_market_pins` | via `run_tool` | Read the values a market purchase for an agent must pin. |
| `priors_market_clear_bid_budget` | via `run_tool` | Prepare clearing your market bid reserve allowance. |
| `priors_market_revoke_nft` | via `run_tool` | Prepare revoking the market's approval for an agent identity NFT. |
| `priors_x_link` | via `run_tool` | Prepare linking an agent to an X post URL as public ERC-8004 metadata. |
| `priors_capabilities` | via `run_tool` | Read which Priors tools are reads, local actions or owner-signed, and which Priors features Oak does not route. |

### 21. Morpho Blue (18)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `morpho_supply_collateral` | yes | Prepare collateral supply to a Morpho Blue market. |
| `morpho_withdraw_collateral` | yes | Prepare collateral withdrawal from Morpho Blue. |
| `morpho_borrow` | yes | Prepare borrowing from a Morpho Blue market. |
| `morpho_repay` | yes | Prepare repayment to a Morpho Blue market. |
| `morpho_supply` | yes | Prepare lending a market's loan token (for example USDG) to a verified Morpho Blue market to earn its supply rate; collateral is separate. |
| `morpho_withdraw` | yes | Prepare withdrawing supplied loan tokens from a Morpho Blue market, or everything with interest; refuses amounts the market cannot pay now. |
| `morpho_status` | yes | Read Morpho Blue market/account state, or discover markets from Morpho's indexer. |
| `morpho_allocator` | via `run_tool` | Read Public Allocator permissions, caps, penalties and candidate shared-liquidity sources for a pinned V2 vault. |
| `morpho_reallocate` | via `run_tool` | Prepare an explicit public allocation from idle or another market, paying only its exact disclosed penalty. |
| `morpho_manage_allocator` | via `run_tool` | Prepare vault-allocator role configuration for public source permissions, caps, adapters and penalties. |
| `morpho_protocol` | via `run_tool` | Read Morpho Blue owner, fee recipient, authorization nonce and optional delegation state. |
| `morpho_manage` | via `run_tool` | Prepare role-checked Blue market creation, interest accrual, owner/fee/IRM/LLTV changes or delegation grant/revoke. |
| `morpho_liquidate` | via `run_tool` | Prepare an unhealthy Blue borrower liquidation funded by exact loan-token approval with a previewed collateral minimum. |
| `morpho_midnight_status` | via `run_tool` | Read Midnight fixed-rate market debt, credit, collateral, maturity, fees, roles and repayment liquidity. |
| `morpho_midnight_take` | via `run_tool` | Prepare a direct Midnight fixed-rate offer take with locally rebuilt pricing, public ratifier proof and exact buyer approval. |
| `morpho_midnight_action` | via `run_tool` | Prepare Midnight collateral supply or withdrawal, fixed-loan repayment, lender credit withdrawal or fee accrual/claim. |
| `morpho_midnight_manage` | via `run_tool` | Prepare role-checked Midnight configuration, fees, delegation or irreversible offer-group cancellation. |
| `morpho_bundle` | via `run_tool` | Prepare atomic Blue supply, withdrawal, collateral borrowing, repayment or same-token migration with bounded public allocation fees. |

### 22. Uniswap Liquidity (31)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `uniswap_add` | yes | State oak.lpWarning first before preparing any liquidity addition. Prepare Uniswap liquidity addition for version v3 or v4. |
| `uniswap_collect` | yes | Prepare Uniswap v3/v4 position fee collection. |
| `uniswap_remove` | yes | Prepare Uniswap v3/v4 liquidity removal. |
| `uniswap_list_positions` | yes | Read Uniswap v3/v4 liquidity positions. |
| `uniswap_create_pool` | via `run_tool` | Prepare creating an empty Uniswap v3 or v4 pool at a starting price you choose; a start more than 500 bps from other live pools of the pair is refused unless accepted. |
| `uniswap_pools` | via `run_tool` | Read the Uniswap v3 and v4 pools for a token pair, deepest first with price-outlier flags, or inspect one v4 pool by ID. |
| `uniswap_v2_pool` | via `run_tool` | Read a Uniswap v2 pair, reserves, LP supply and the wallet's LP balance. |
| `uniswap_v2_add` | via `run_tool` | Prepare Uniswap v2 liquidity addition with exact desired-amount approvals and bounded minimums. |
| `uniswap_v2_remove` | via `run_tool` | Prepare Uniswap v2 liquidity removal with an exact LP approval and both assets paid to this wallet. |
| `uniswap_quote` | via `run_tool` | Read an on-chain Uniswap v2/v3/v4 exact-input or exact-output quote for an explicit route. |
| `uniswap_swap` | via `run_tool` | Prepare an explicit Uniswap v2/v3/v4 swap with the caller's absolute minimum output or maximum input. |
| `uniswap_fees` | via `run_tool` | Read current Uniswap v3/v4 position fee growth and collectable amounts, with optional v3 lifetime history. |
| `uniswap_batch` | via `run_tool` | State oak.lpWarning first before preparing any liquidity addition. Prepare up to 20 Uniswap v4 liquidity additions, collections or removals in one transaction. |
| `uniswap_token_jar` | via `run_tool` | Read the protocol TokenJar assets, releaser, payment threshold and nonce. |
| `uniswap_token_jar_release` | via `run_tool` | Prepare releasing protocol TokenJar assets to this wallet at the specified nonce and maximum payment. |
| `uniswap_auction_status` | via `run_tool` | Read a factory-verified CCA auction and optional bid status. |
| `uniswap_auction_bid` | via `run_tool` | Prepare a bid owned by this wallet on a factory-verified CCA auction. |
| `uniswap_auction_exit` | via `run_tool` | Prepare a full or partial exit for this wallet's CCA bid using explicit checkpoint hints. |
| `uniswap_auction_claim` | via `run_tool` | Prepare claiming sale tokens for this wallet's exited CCA bids. |
| `uniswap_auction_checkpoint` | via `run_tool` | Prepare updating a factory-verified CCA auction checkpoint. |
| `uniswap_auction_sweep_currency` | via `run_tool` | Prepare sweeping CCA proceeds to the auction's fixed creator recipient. |
| `uniswap_auction_sweep_tokens` | via `run_tool` | Prepare sweeping unsold CCA tokens to the auction's fixed creator recipient. |
| `uniswap_auctions` | via `run_tool` | Read canonical CCA auction creation events in a bounded block window. |
| `uniswap_wrap` | via `run_tool` | Prepare wrapping ETH or unwrapping WETH at the pinned contract, with a separate human confirmation. |
| `uniswap_protocol_status` | via `run_tool` | Read Uniswap v2/v3/v4 protocol owner and fee-controller roles. |
| `uniswap_protocol_admin` | via `run_tool` | Prepare a Uniswap protocol role or fee change after checking this wallet's current authority. |
| `uniswap_position_status` | via `run_tool` | Read a Uniswap v3/v4 NFT owner and exact approved spender. |
| `uniswap_position_manage` | via `run_tool` | Prepare transferring, approving, revoking or burning one owned Uniswap position NFT; operator-wide grants are refused. |
| `uniswap_create_auction` | via `run_tool` | Prepare creating, exactly funding and activating a standalone CCA auction, with creator recipients pinned to this wallet. |
| `uniswap_swap_batch` | via `run_tool` | Prepare caller-selected split or mixed Uniswap v2/v3/v4 routes in one transaction, preserving every trade bound. |
| `uniswap_oracle` | via `run_tool` | Read a factory-verified Uniswap v3 time-weighted mean tick over the requested observation window. |

### 23. Hookr (34)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `hookr_create` | yes | Prepare a Hookr sidecar limit order. |
| `hookr_cancel` | yes | Prepare Hookr order cancellation. |
| `hookr_fill` | via `run_tool` | Prepare fill of an eligible Hookr order. |
| `hookr_claim_bounty` | via `run_tool` | Prepare an eligible Hookr bounty claim. |
| `hookr_open_orders` | via `run_tool` | Read public Hookr orders from any trader that a keeper could fill, with expiry, bounty and estimated gas economics, page by page. |
| `hookr_orders` | yes | Read the signing wallet's Hookr order history, newest first and including terminal states, page by page. |
| `hookr_order` | via `run_tool` | Read one Hookr order by ID, including filled and cancelled orders. |
| `hookr_pools` | via `run_tool` | List official Hookr pool keys with token metadata, fees and Hook Blocks, optionally filtered by token. |
| `hookr_pool` | via `run_tool` | Read Hookr pool rules and keeper bounty floor. Supply side, amountIn and minAmountOut for current on-chain bounty bounds; a pool ID alone cannot determine an order-specific floor. |
| `hookr_quote` | via `run_tool` | Read Hookr's informational trade check for a pool, side and exact input; it is not permission to trade. |
| `hookr_relay` | via `run_tool` | Prepare a Hookr forwarder relay of a trader-signed swap intent; the local wallet is the named relayer and pays gas. |
| `hookr_relay_receipt` | via `run_tool` | Read a mined relay's executed intent and relayer fee from the Hookr forwarder. |
| `hookr_contracts` | via `run_tool` | Read Hookr contract coverage and typed function schemas: swaps, launches and dev buys, liquidity, saved hooks, own hooks, LP boost, programs, referrals, claims, registry and treasury administration. Filter contract/function to fetch only the needed schema. No network request. |
| `hookr_read` | via `run_tool` | Read a pinned Hookr contract function. Fetch its exact parameter schema with hookr_contracts {contract,function}; no signing, subscription or identity required. |
| `hookr_action` | via `run_tool` | Prepare a pinned Hookr fungible-token action from an exact schema in hookr_contracts, with local reconstruction and human confirmation. NFT/6909 grants and registerSigned remain blocked. |
| `hookr_launch_options` | via `run_tool` | Read pinned Hookr launch settings, live ETH launch fee, agent gate health, requested reviewer sets and admission caps at one named block. No launch transaction. |
| `hookr_launch` | via `run_tool` | Launch a public fixed-supply token and one agents-only Hookr pool with exact deposit caps, atomic refunds and human approval. New tokens only; no locks. |
| `hookr_lp_position` | via `run_tool` | Read one Launcher family LP position: owner, principal, uncollected LP fees, separate core credits, pending pool recapture, locks and read completeness. NFT/account reads await integration. |
| `hookr_lp_add` | via `run_tool` | State oak.lpWarning first before preparing any liquidity addition. Add exact liquidity to your Hookr family’s existing range with finite caps, approval reset, refunds and cleanup. Human approval required. |
| `hookr_lp_remove` | via `run_tool` | Remove exact Hookr family liquidity to your wallet, with principal minima enforced separately from LP fees. Principal locks apply. |
| `hookr_lp_collect` | via `run_tool` | Collect Hookr family LP fees with zero principal removed, including during principal locks. Report core claim credits separately. |
| `hookr_lp_positions` | via `run_tool` | List this wallet’s Launcher family LP positions at a fixed block with bounded event pagination and ownership checks. Continue nextCursor until complete; empty partial pages prove no absence. |
| `hookr_release` | via `run_tool` | Read verified release contracts, block and recapture lane. |
| `hookr_blocks` | via `run_tool` | Read all Hook Blocks and their current availability. |
| `hookr_kings` | via `run_tool` | Read King of the Pool rounds, leaders, pots and endings. |
| `hookr_claims` | via `run_tool` | Read the signing wallet's prizes, royalties, recapture and PoolManager claims. |
| `hookr_revenue_tokens` | via `run_tool` | Read revenue tokens, tokenizer provenance, streams and income, page by page. |
| `hookr_revenue_token` | via `run_tool` | Read a revenue token, stream endings, income, drops and the signing wallet's claims. |
| `hookr_hook` | via `run_tool` | Read shared or owned hook provenance, ownership, allowed blocks, opening and pools. |
| `hookr_api_read` | via `run_tool` | Read Hookr public catalog, protocol stats, pool APR, revenue directory/income, or one token's doors/mark. Marks are project metadata, not investment or security endorsements. |
| `hookr_revenue_read` | via `run_tool` | Read a registered Hookr revenue token or its derived drop box: balance, claimable, terms and indices. Checks tokenizer provenance on chain. |
| `hookr_revenue_action` | via `run_tool` | Preview holder income/drop claims or permissionless sync/syncRange/syncSome on a registered Hookr revenue token. No approvals; local human confirmation required. Claims and syncs are separate actions. |
| `hookr_addon_read` | via `run_tool` | Read factory-verified current Hookr revenue time shares, day wrappers or compounders: locks, day income, unwrap baskets, bands and side assets. Open factories via hookr_action. |
| `hookr_addon_action` | via `run_tool` | Prepare a factory-verified current Hookr compounder action with exact funding and human confirmation. Time-share and day-wrapper actions await ERC-6909 trace and journal support. |

### 24. Meridian (18)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `meridian_browse` | yes | Search and page through Meridian Predict markets or look up an open condition. Prices 0 and 1 may indicate a resolved or inactive market; check resolution, status and liquidity before treating them as tradable prices. |
| `meridian_positions` | yes | Read Meridian prediction positions page by page. |
| `meridian_settle` | via `run_tool` | Prepare settlement of eligible Meridian positions. |
| `meridian_redeem` | yes | Prepare redemption of resolved Meridian positions. |
| `meridian_buy` | via `run_tool` | Buy a Meridian Predict position via RFQ with an exact stake approval and human confirmation. Minimum stake is set by makers; observed above 2 USDe on 2026-11-01 (5 USDe drew a bid). No bid means no purchase. |
| `meridian_sell` | yes | Prepare a Meridian sell with bridge-managed EIP-712 RFQ continuation/signing. |
| `meridian_perps_read` | via `run_tool` | Omit resource to discover every parameter schema locally. Otherwise read one official Meridian perps API page. Use nextCursor while hasNext is true. |
| `meridian_perps_order` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_cancel` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_withdraw` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_convert` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_signer` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_referral` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_batch` | via `run_tool` | Blocked: Meridian perps signatures remain disabled by the signing contract pending expiry policy and a registered local submission path. Never supply a signature manually. |
| `meridian_perps_deposit` | via `run_tool` | Preview an exact ERC-20 approval and exchange deposit. First deposit registers the subaccount. Wait for sequencer processing before trading. |
| `meridian_perps_finalize` | via `run_tool` | Preview same-chain withdrawal finalization for this owner after on-chain initiation. API acceptance alone does not permit finalization. |
| `meridian_perps_stream` | via `run_tool` | Read a bounded sample of an official perps WebSocket stream, then close. Empty timed-out samples do not prove no activity. L2Book starts with up to 100 levels per side, followed by deltas. |
| `meridian_predict_read` | via `run_tool` | Omit operation to discover variable schemas locally. Run fixed official Predict app reads: competitions/rules/standings, historical predictions/trades, categories/tags/questions/odds, collateral transfers and account statistics. Follow pageInfo cursors and preserve filters. Indexed data can lag the chain. |

### 25. TickerSpring (50)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `tickerspring_contract_read` | via `run_tool` | Inspect or call published TickerSpring read-only ABIs on pinned contracts; integers are decimal strings. |
| `tickerspring_stats` | via `run_tool` | Read TickerSpring public protocol totals. |
| `tickerspring_vault_history` | via `run_tool` | Read a pinned TickerSpring vault price or earnings history. |
| `tickerspring_basket_history` | via `run_tool` | Read TickerSpring basket history. |
| `tickerspring_strategy_tokens` | via `run_tool` | Scan TickerSpring grid or dip-ladder candidates and preserve weak results. |
| `tickerspring_ranges` | via `run_tool` | Read historical TickerSpring grid range candidates for a USDG budget. |
| `tickerspring_backtest_grid` | via `run_tool` | Backtest a TickerSpring grid with base-unit USDG budget; estimates only. |
| `tickerspring_backtest_ladder` | via `run_tool` | Backtest TickerSpring one-shot ladder levels using USDG budgets; estimates only. |
| `tickerspring_strategy_finder` | via `run_tool` | Compare TickerSpring strategy and vault past results with period, category and style filters. |
| `tickerspring_strategy_detail` | via `run_tool` | Read TickerSpring strategies for one token and period. |
| `tickerspring_strategy_track_record` | via `run_tool` | Read past TickerSpring strategy-board picks, including losses. |
| `tickerspring_backtest_strategy` | via `run_tool` | Backtest a published TickerSpring strategy variant; custom settings need a published schema. |
| `tickerspring_agents` | via `run_tool` | Read the TickerSpring public agent directory. |
| `tickerspring_agent_vault` | via `run_tool` | Read a TickerSpring backing vault and this wallet state; no backing transaction is prepared. |
| `tickerspring_trade_directory` | via `run_tool` | Read TickerSpring branded swap and alternative limit/TWAP deployments and availability. |
| `tickerspring_trade_token` | via `run_tool` | Read metadata for a TickerSpring trade token by address. |
| `tickerspring_trade_quotes` | via `run_tool` | Compare TickerSpring aggregator quotes without preparing a trade. |
| `tickerspring_spring_config` | via `run_tool` | Read TickerSpring Spring Orders configuration, markets, keeper status and retired deployments. |
| `tickerspring_owner_report_card` | via `run_tool` | Hand off private TickerSpring report cards to owner sign-in on the official site. |
| `tickerspring_sign_request` | via `run_tool` | Inspect a stored TickerSpring sign request for this wallet; never executes stored calldata. |
| `tickerspring_instructions` | via `run_tool` | Link to TickerSpring official instructions, API schema or wallet-policy references. |
| `tickerspring_order_accounting` | via `run_tool` | Prepare direct realization of owned limit-order accounting or claim one currency; provider report-card attribution is unavailable. |
| `tickerspring_products` | via `run_tool` | Read TickerSpring products and minimums: orders/ladder levels 10 USDG, grids 11, ladder planner 55; vaults use minDepositUnits, basket creation 25 USDG. |
| `tickerspring_tokens` | via `run_tool` | Read TickerSpring tokens with open limit/grid flags. Filter by query or category; unfiltered or sort-only volume responses can be incomplete. |
| `tickerspring_vaults` | via `run_tool` | List TickerSpring agent vaults with status, minimum, capacity, fee and withdrawal modes, or read one vault. |
| `tickerspring_baskets` | via `run_tool` | List TickerSpring baskets with holdings, weights and fees, or read one basket including this wallet's holding. |
| `tickerspring_order_exit_preview` | via `run_tool` | Simulate cancelling a TickerSpring order and read the refundable assets and proceeds now; it returns no executable transaction. |
| `tickerspring_account` | yes | Read the full TickerSpring account: vault requests and shares, basket holdings, strategy state, orders and buckets. |
| `tickerspring_activity` | via `run_tool` | Read TickerSpring account activity since a returned cursor; the first call sets a baseline and no background job is created. |
| `tickerspring_report_card` | via `run_tool` | Read TickerSpring's report card with the provider's losses, counts and conservative hit rate unchanged. |
| `tickerspring_plan` | via `run_tool` | Plan a TickerSpring grid (at least 11 USDG) or dip ladder (55 USDG) from price history; historical estimates, not promised returns. |
| `tickerspring_swap_quote` | via `run_tool` | Read a TickerSpring branded swap quote with typed base-unit input, expected output and minimum; swap execution is not offered. |
| `tickerspring_candles` | via `run_tool` | Read TickerSpring token price candles. |
| `tickerspring_basket_plan` | via `run_tool` | Plan a TickerSpring basket mix, showing thin liquidity and historical results, before creating it. |
| `tickerspring_tx_status` | via `run_tool` | Read this wallet's receipt for a TickerSpring transaction hash; inclusion does not prove a keeper settled. |
| `tickerspring_spring_orders` | via `run_tool` | Point to TickerSpring's site for Spring Orders, which have no agent route; it signs nothing. |
| `tickerspring_capabilities` | via `run_tool` | Read TickerSpring support and minimums: orders/ladder levels 10 USDG, grids 11, ladder planner 55; vaults use minDepositUnits, basket creation 25 USDG. |
| `tickerspring_grid` | via `run_tool` | Prepare a repeating TickerSpring grid (at least 11 USDG): open, collect, set repeat or close, with exact approvals and protected minimums. |
| `tickerspring_ladder_strategy` | via `run_tool` | Prepare management of an existing TickerSpring ladder strategy: collect, set repeat or close; opening one is not offered. |
| `tickerspring_ladder` | via `run_tool` | Prepare 2 to 20 independent TickerSpring limit-order ladder levels, each at least 10 USDG notional, with one exact approval; manage each order separately. |
| `tickerspring_basket_make` | via `run_tool` | Prepare creating a TickerSpring basket with permanent name, symbol, weights and fee, plus a first deposit worth at least 25 USDG, through the pinned Maker. |
| `tickerspring_vault_deposit` | via `run_tool` | Prepare a TickerSpring vault deposit using its current minDepositUnits from tickerspring_vaults, exact USDG approval and a minimum-share floor; a keeper settles shares later. |
| `tickerspring_vault_cancel_deposit` | via `run_tool` | Prepare cancelling an unfilled TickerSpring vault deposit request. |
| `tickerspring_vault_withdraw` | via `run_tool` | Prepare a direct TickerSpring vault exit for shares as USDG or in kind, with protected minimums. |
| `tickerspring_basket_buy` | via `run_tool` | Prepare a TickerSpring BasketZap purchase with a minimum basket-token output; check the current quote for the basket and payment-token minimum. |
| `tickerspring_basket_sell` | via `run_tool` | Prepare a TickerSpring basket sale through BasketZap with an exact basket-token approval and a minimum payment output. |
| `tickerspring_create` | yes | Prepare a TickerSpring limit order; minimum order size is 10 USDG notional. Provider minimum/default slippageBps is 500 (5%); lower values are refused before prepare. Includes unopened-market starting-price bundles. |
| `tickerspring_cancel` | yes | Prepare TickerSpring order cancellation. |
| `tickerspring_claim` | yes | Prepare TickerSpring order proceeds/token claim. |
| `tickerspring_orders` | via `run_tool` | Read TickerSpring wallet orders. |

### 26. Clanker (17)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `clanker_launch` | yes | Prepare a Clanker token launch. |
| `clanker_claim` | via `run_tool` | Prepare an eligible Clanker creator-fee claim. |
| `clanker_browse` | yes | Browse Clanker token launches. |
| `clanker_status` | via `run_tool` | Read a Clanker token's pool, reward administrators and recipients, fee preferences, collected fees and this wallet's balance. |
| `clanker_update_reward` | via `run_tool` | Prepare changing one Clanker reward row's recipient, admin or fee preference; naming a new recipient or admin hands over future fees or control. |
| `clanker_update_token` | via `run_tool` | Prepare a Clanker token admin action: update the image or metadata, name a new admin, verify, delegate votes to a named address, or burn your own tokens. |
| `clanker_airdrop_proofs` | via `run_tool` | Read this wallet's published Clanker airdrop proofs for a token, checked against the on-chain root. |
| `clanker_vault_status` | via `run_tool` | Read a Clanker token vault's allocation, lockup and vesting times, admin and claimable amount. |
| `clanker_vault_claim` | via `run_tool` | Prepare claiming a Clanker vault's vested tokens; they are paid to the recorded vault admin even if another wallet calls. |
| `clanker_vault_update_admin` | via `run_tool` | Prepare naming a new admin for a Clanker vault allocation, who then receives all future vault claims. |
| `clanker_airdrop_tree` | via `run_tool` | Compute a Merkle root and public proofs for up to 200 Clanker airdrop recipients; nothing is published or sent. |
| `clanker_airdrop_status` | via `run_tool` | Read a Clanker airdrop's admin, root, supply, claims and lockup, and this wallet's claimable amount for an allocation. |
| `clanker_airdrop_claim` | via `run_tool` | Prepare claiming this wallet's Clanker airdrop allocation with its Merkle proof; tokens are paid to this wallet. |
| `clanker_airdrop_manage` | via `run_tool` | Prepare a Clanker airdrop admin action: name a new admin, set the Merkle root, or reclaim the unclaimed tokens to a named recipient, which ends recipient claims. |
| `clanker_protocol_admin` | via `run_tool` | Prepare a Clanker protocol owner or admin operation, such as setting the admin, hooks, lockers or extensions, claiming team fees, withdrawing balances to a named recipient, or transferring or renouncing ownership. |
| `clanker_store_fees` | via `run_tool` | Prepare depositing fee tokens into the Clanker fee locker for a named fee owner, with an exact approval; authorized depositors only. |
| `clanker_claim_for` | via `run_tool` | Prepare paying out a named fee owner's collected Clanker fees; anyone may call it and the payout always goes to that fee owner. |

### 27. pools.trade (13)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `poolstrade_launch` | yes | Prepare a pools.trade token launch. |
| `poolstrade_buy` | yes | Prepare a pools.trade token purchase. |
| `poolstrade_sell` | yes | Prepare a pools.trade token sale. |
| `poolstrade_collect` | via `run_tool` | Prepare pools.trade creator-fee collection. |
| `poolstrade_claim` | via `run_tool` | Prepare an eligible pools.trade claim. |
| `poolstrade_browse` | via `run_tool` | Browse pools.trade launches from on-chain logs over a block range, with paging. |
| `poolstrade_balance` | via `run_tool` | Read your balance of a pools.trade token, identified by token address or launch transaction. |
| `poolstrade_status` | yes | Read a pools.trade launch's status, token and fee position. |
| `poolstrade_launch_options` | via `run_tool` | Read pools.trade launch options, limits and fee settings. |
| `poolstrade_fee_transfer` | via `run_tool` | Prepare transferring a pools.trade fee position to a new owner. |
| `poolstrade_fee_approve` | via `run_tool` | Prepare approving a spender for a pools.trade fee position. |
| `poolstrade_transfer` | via `run_tool` | Prepare transferring a pools.trade token to another address. |
| `poolstrade_collect_many` | via `run_tool` | Prepare collecting fees from several pools.trade positions in one transaction. |

### 28. Agent Wormhole (2)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `wormhole_token_check` | via `run_tool` | Read and verify a free signed token metadata snapshot on chain 4663 from Agent Wormhole. Missing, stale or invalid evidence gives no current verdict; this is not a contract audit. |
| `wormhole_scan_text` | via `run_tool` | Scan untrusted text offline on this computer for instruction shapes with Agent Wormhole rules. Never uploads text; allow is not proof of safety and abstain means unknown. |

---

## Declarative Project Recipes (`oak-recipe/v1`)

| Tool | In `tools/list` | One-line public description |
| :--- | :--- | :--- |
| `<project>.<name>` | yes | Run an installed data-only recipe, labelled as-is, not reviewed by Oak; names depend on installed recipes. |
