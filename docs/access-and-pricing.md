# Access and pricing

Oak has **no subscription** on Robinhood Chain mainnet (chain ID `4663`): reads, quotes, and previews are free, and some actions carry an Oak fee, always shown in the approval summary before you say yes.
Anyone can discover tools and call reads such as `find_token` without an identity.
Hosted actions require a verified ERC-8004 identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`), except the free `gloam_claim` action.
Installing the published npm packages is free under their [own license](../LICENSE-PACKAGES.md).
The [live deployment record](../contracts/deployments/README.md) lists the contracts and receipt hashes.

## Identity and chat confirmation

- **Read tools:** `find_token`, `balances`, `price`, `quote`, `preview`, `history`, `positions`, `account`, and module reads work without an ERC-8004 identity.
- **ERC-8004 identity setup (`oak setup` / `oak_setup`):** Public identity registration (`oak setup register`) mints an ERC-8004 NFT on chain, publishes the profile plus the mandatory `oak.registrar = oak` marker, and costs ETH network fees. Linking an existing identity (`oak setup link <agentId>`) is gasless; an external owner signs the link challenge in their own terminal. Unlinking (`oak identity unlink`) is also gasless.
- **Yes-or-no confirmation in chat:** Every action runs in two steps. First, the agent calls a listed common action tool (`swap`, `send`, `lend`, `withdraw`, `borrow`, `repay`, `bridge`) or `oak_prepare` with `{"name": "<tool>", "arguments": {...}}`, which builds and simulates the transaction via `eth_simulateV1` without signing, giving a six-part summary (what leaves the wallet, what comes back, the destination contract, the exact approval, the estimated network fee, and the USD value) plus a single-use `actionId` and UTC expiry. The agent shows that summary in chat and asks for a yes or no. When you say yes, the agent calls `oak_execute` with `{"actionId": "<the exact actionId>"}`, which re-simulates immediately before signing, checks that terms have not worsened and checks your optional daily spending limit in USD, and signs locally.
- **Optional daily spending limit in USD (`oak_spending_limit`):** On first run, the agent asks once in chat whether you want a daily spending limit in USD. Skipping leaves no limit. You can set, change, or clear the daily spending limit anytime in chat via `oak_spending_limit`.

## How Oak earns income

Oak earns a 0.25% fee on swaps, bridges, sends, and Morpho bundles, plus an optional 10% Clanker LP reward share and partner referral fees.

- **Swaps and bridges (`0.25%`, `25 bps`):** Charged on direct Uniswap swaps (taken from the output), official stock-token swaps via `priors_stock_quote` and `priors_stock_swap` (taken from the output), KyberSwap swaps (taken from the input), Velora swaps (taken from the output), and Relay bridges and swaps. FOBO, Pons, and Hookr routes carry 0 bps from Oak.
- **Plain sends (`send`, `0.25%`, `25 bps`):** Added on top (`floor(amount * 25 / 10000)` in the token being sent to `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`), so the recipient receives the full amount. Dust too small to carry a fee (`< 400` base units) and sends to or from the Oak treasury (`0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`) carry none.
- **Morpho bundles (`morpho_bundle`, `0.25%`, `25 bps`):** Charged on the loan amount across `supply`, `withdraw`, `supplyCollateralAndBorrow`, `repayAndWithdrawCollateral`, and `migrateBorrowPosition` to `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf` (deducted on supply, withdraw, and borrow; added on top on repay and migrate). Collateral-only steps and ordinary `morpho_supply`, `morpho_withdraw`, `morpho_borrow`, `morpho_repay`, `morpho_supply_collateral`, and `morpho_withdraw_collateral` carry none.
- **Clanker launches (`clanker_launch`):** An opt-in choice (`oakRewardShare: true`) to share 10% (`1000 bps`) of future distributable LP creator rewards with Oak (`0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`); off unless the person chooses it.
- **hood.ag referrals:** 5% referral fee on `.hood` name registrations and 4% on marketplace resales, with matching buyer discounts (zero on treasury self-referral).
- **Borro Bookrunners referral share:** 10% of the Borro vault interest fee on tagged deposits — 100% of that share to Oak for the first 12 months, then 50%, paid monthly in USDG. Deposits route via `BorroBuilders` (`0x082Ae609bdC7ccEec0C58B2361a21c49dc2aE291`) with referral code `oak` and on-chain `minShares` protection, or fall back to a direct vault deposit when `BorroBuilders` is unavailable.

ETH network fees and project fees are separate.

## `$OAK` buybacks and burns

25% of Oak's income buys back and burns $OAK.
Holding $OAK has no access perks. Oak uses 25% of its income to buy back and burn $OAK.

1. At least once a month, the operator converts 25% of that period's swap, bridge, send, Morpho bundle, Clanker LP reward share, and partner referral fee income to USDG.
2. The operator transfers that USDG to `OakBurner` (`0x0704AE41934EE9b71A85cBd308786CfE503108f4`) on Robinhood Chain first.
3. Burns depend on price notes from Oak's server. The operator wallet fetches a caller-bound `for: "burner"` price note from the hosted service (`OakOracle` verifies that `note.wallet == msg.sender`, that the note is within 300 seconds, and that the signed `$OAK`-per-ETH rate is within the 50% oracle guard band, while `OakBurner` enforces its tighter 10% live-spot check and output floor).
4. The operator calls `buyAndBurn(usdgIn, note, sig)` on `OakBurner` in chunks of at most `oracle.liquidityUsdgE6() / 200` (`0.5%` of live pool USDG liquidity per call), swapping USDG -> WETH -> `$OAK` and calling `oak.burn()` on the bought `$OAK`, lowering `totalSupply`.
5. Public burn announcements state `"we burned"` and link the on-chain `OakBurner` transactions.

Since the Oak 0.3.10 server release (2026-11-16), burner notes are issued only to the operator wallet. There is no permissionless fallback if the server withholds notes or is unavailable. The owner address (`safe`) controls the price signer on `OakOracle` and can pause all note-based actions, such as burns, by setting it to zero.

The revised burner source is not deployed yet. It limits each call to the lower of 0.5% of live pool USDG liquidity and 250 USDG, requires the first leg to deliver at least 99.5% of the WETH implied by the 30-minute ETH/USD average, and re-derives the OAK floor from the WETH actually received using the higher of the note price and live spot. OAK must have 18 decimals. Tokens other than USDG sent to `OakBurner` cannot be recovered.

The revised source gives a sweep 90 days of notice. Only a burn of at least 1% of the armed balance, rounded up, or one that uses up the armed remainder disarms it. A sweep pays at most the part of the armed balance not yet burned, bounded by the current USDG balance, and is void if the price signer changes after arming; anyone can flag that change.

Sending OAK to `0x000000000000000000000000000000000000dEaD` leaves `totalSupply` unchanged.

See [security](security.md) for the exact on-chain oracle and burner checks. The legacy `OakSubscription` (v2) billing contract (`0x5e0d93D4bad53388839Ac5A53dB716b70d8606A8`) remains deployed on Robinhood Chain and is unused (`0xF1C5d40997e1151B125a41e822C4278b153c4610` has no code on chain: never deployed or not at that address).
