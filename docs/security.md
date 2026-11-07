# Security, Custody, and Authority

**Release scope:** Yes-or-no chat confirmation (preparing with a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after a yes) and local transaction guards apply in **0.3.0**; see the [live deployment record](../contracts/deployments/README.md). Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).

The treasury and contract admin is the single-owner wallet `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`. One owner key can spend treasury funds, replace the price signer on `OakOracle`, and arm or execute the 90-day stuck-funds sweep on `OakBurner`. Legacy v1 and v2 billing contracts (`0xF1C5d40997e1151B125a41e822C4278b153c4610` and `0x5e0d93D4bad53388839Ac5A53dB716b70d8606A8`) remain deployed on Robinhood Chain and are unused. There is no second-signature requirement. Key compromise exposes these powers; key loss can make treasury funds and administration inaccessible. It cannot spend user wallet balances. Safe support is an optional deployment profile, not the launch setup.

---

## 1. Reporting a Vulnerability

Do not report security vulnerabilities in public GitHub issues, pull requests, or public channels on X.

Use **GitHub private vulnerability reporting** on the official OakAgentKit repository:

- **Report:** [GitHub private vulnerability reporting](https://github.com/OakAgentKit/oak/security/advisories/new)

Include in your report:

1. The affected surface (local CLI/MCP add-on, 34 ecosystem connectors, smart contracts in `contracts/`, hosted service, or deployed contracts on Robinhood Chain `4663`).
2. Minimal reproduction steps, proof-of-concept test or Foundry test (`forge test`), and the exact commit SHA or package version.
3. The concrete impact against the authority boundaries documented below.

We acknowledge private advisory submissions within **48 hours**, provide a triage assessment within **7 days**, and coordinate remediation and public disclosure once a fix or contract migration is verified. Good-faith security research on local test environments or testnet (`46630`) without disrupting production services or third-party users is welcomed under safe harbor.

---

## 2. Where Your Key Lives (Local Self-Custody)

Oak is built so that **your private key never leaves your computer** and **the hosted Oak service never sees your key and never signs or sends a transaction**: **your swaps and deposits go straight from your wallet to the project**.

- **Owner-run terminal boundary (`oak init` & `oak export`):** Both commands require an interactive terminal (`isTTY`) and must be run **in your own terminal, never through the agent**. Even if an agent can allocate a pseudo-terminal (`PTY`), running `oak init` and `oak export` yourself keeps your 24 recovery words and private key out of agent prompts, tool outputs, and logs. **Oak cannot recover a lost key.**
- **Encryption at rest (`~/.oak/wallet.enc`):** Your 32-byte secp256k1 private key is encrypted with `AES-256-GCM` (file mode `0600`, directory mode `0700`; symlinks and hardlinks are rejected). Automatic wallets store a random encryption key in the persistent OS keychain or an owner-only local file; no passphrase is requested. Reading both wallet and fallback key files can unlock the wallet. Existing passphrase wallets retain `scrypt` (`N = 131072, r = 8, p = 1`) and require terminal unlock.
- **Argument redaction:** Both the local MCP bridge and the hosted service reject any tool argument containing `private_key`, `secret_key`, `wallet_key`, `mnemonic`, `seed`, `seed_phrase`, or `recovery_phrase`.
- **Local validation before signing:** The hosted service builds ecosystem transactions. The add-on validates swap calldata locally using the core validators: pinned module routers and executors, input and output tokens, exact input, wallet recipient, native value and quoted minimum output. Quotes must have been requested in this local session. Swap approvals equal the held quote input. Other approvals cannot exceed the reconstructed requested input (Uniswap v4 liquidity adds allow up to 0.5% headroom, rounded up to the next base unit, within caller caps to tolerate small price ticks; unused ETH is refunded in the same transaction), so no unconditional zero-residual-allowance guarantee is made. Unlimited ERC-20/Permit2 approvals, incremental allowance grants, unsupported permit variants and blanket operator approvals are refused. Non-swap destinations and approval spenders must belong to the local module deployment set; factory-backed destinations are resolved through pinned factories with public chain reads. For other server-built actions, the add-on resolves inputs from the request and public chain reads, then refuses local simulation outflows outside those inputs. Implicit debt amounts use the local core module's calculation. An unknown asset, unmatched amount, missing transfer log or unsupported local simulation stops signing. Complete `eth_simulateV1` results, logs and `traceTransfers` are required. `debug_traceCall` is optional: if supported, nested delegate targets are pinned; a confirmed unsupported-method response selects simulation-only mode and leaves that delegatecall visibility as a residual risk. Malformed traces, transport errors, or failure after tracer support was established stop signing. A `merkl_claim` must claim for this wallet alone, and a Relay inbound deposit (`relay_bridge_in`) must name this wallet as its depositor. For inbound bridging, the core preserves full protocol order data and the add-on independently recomputes Relay's supported v1 full-order hash with the local core hasher. It must equal the deposit calldata order ID. The add-on binds the hashed origin/input, destination chain/token, recipient, minimum/slippage floor, empty output calls, wallet refund recipients/currencies/floors and deadlines to the local request, before any approval and on every rebuild. Confirmation renders those checked terms, and the earliest output/refund deadline retains 30 seconds of signing headroom. Missing data, unknown versions or chains, mismatched hashes or unwanted terms stop signing. Hosted IDs and request-history metadata alone cannot authorize the deposit. Hash verification proves the terms committed by the funded ID, not future destination settlement; a call that differs stops signing. Combined Relay swap/bridge requests currently fail closed; quote and execute the swap separately, then bridge.
- **Two-step chat confirmation (`oak_prepare` and `oak_execute`):** Every action prepares a preview first (by calling a listed common action tool such as `swap`, `send`, `lend`, `withdraw`, `borrow`, `repay`, or `bridge`, or `oak_prepare` with `{"name": "<tool>", "arguments": {...}}`) without signing, and gives a six-part summary (what leaves your wallet, what comes back, the destination contract, the exact approval, the estimated network fee, and the USD value) plus a single-use `actionId` and UTC expiry. The agent shows that summary in chat and asks for a yes or no. When you say yes, the agent calls `oak_execute` with `{"actionId": "<the exact actionId>"}`. The add-on re-simulates immediately before signing, checks that terms have not worsened and checks the optional daily spending limit in USD, and signs locally. Gasless identity-link/unlink and Meridian RFQ continuations have no EVM transaction preview; their confirmation binds to the EIP-712 typed-data hash. Changed bytes or worsened terms require a new prepare step (`oak_prepare` or the action tool) and confirmation. Reads and session/request authentication signatures do not prompt. Identity registration, approval cleanup and new recovery signatures do prompt. An identical already-signed journal rebroadcast creates no new signature. Quoted fields in confirmation summaries show control, format, line-separator and other invisible characters as `\uXXXX` escapes (`\u{…}` above `U+FFFF`), so hidden characters cannot disguise what you approve.
- **Optional daily spending limit in USD (`oak_spending_limit`):** On first run, the agent asks once in chat whether you want to set a daily spending limit in USD (skipped means no limit). You can set, change, or clear the daily spending limit anytime in chat via `oak_spending_limit`. When a daily limit is set, `oak_execute` checks the action's USD value against your remaining daily limit before signing. There is no operator asset allowlist.
- **Preview, fees and recovery:** The bridge may reuse an identical hosted preview from the same block within 12 seconds. This hosted-cache reuse is separate from the sender's local work: it simulates the ordered sequence, simulates each transaction with exact gas, fee and nonce fields during preparation (`oak_prepare` or a listed action tool), then freshly simulates the immutable transaction during `oak_execute` immediately before signing. Changed transfer estimates or wallet approval events, missing logs, and reverts stop signing, including for fee replacement and nonce cancellation. It retains ETH gas headroom, expiry checks and the per-wallet journal (`~/.oak/<address>.pending.json`) written before broadcast. Human approval does not extend a quote or prepared transaction's expiry. Prepared action records are persisted locally in `~/.oak/pending-actions/<address>.json` with a five-minute expiry. Consuming an action removes its unsigned payload before execution; the summary and consumed marker can remain until a later preparation removes expired records. Signed transaction bytes and hashes remain in the journal until reconciled under the existing retention rules. Simulated transfers are estimates, exclude gas, and do not prove inclusion-time state, sellability, token behavior or external settlement, including Relay destination fills and Meridian relayer execution.

A partial Uniswap or Pons spend can leave a bounded allowance: the unspent part of the finite approval. For Uniswap v4 liquidity adds, that remainder is bounded by the caller cap. Use `oak_cleanup_allowances` to preview and confirm revocation as a separate local operation; it needs ETH for network fees and remains available without an identity.

### Oracle tick-math provenance

`OakTickMath.sqrtRatioAtTick` is adapted from Uniswap v4-core
`src/libraries/TickMath.sol` at commit
`0f17b65aa61edee384d5129b7ea080f22905faa0`, under MIT. Oak retains only the
tick-to-sqrt-price function, renames it, uses a plain custom error, and removes the
unused reverse conversion, spacing helpers, constants, and imports; the calculation
and its constants are unchanged. A GPL-2.0-or-later, test-only snapshot of Uniswap
v3-core at commit `5ea68a77cb541c6b3812df783be71ba8c081e25f` remains solely as a
differential oracle and is never deployed.

The default Foundry suite explicitly runs 256 fuzz cases. The dedicated `tickmath`
profile runs 100,000 random differential and adjacent-monotonicity cases. Deterministic
tests cover both bounds, every power-of-two bit transition, and every 1,000th tick plus
its neighbors. An opt-in exhaustive test checks all 1,774,545 valid ticks; out-of-range
tests cover both sides, and a deliberate one-unit mutant is the positive control.

---

## 3. ERC-8004 Identity Verification & Unlinking

Read tools (`find_token`, `balances`, `price`, `quote`, `preview`, `history`, `positions`, `account`, and module reads) work without an identity. Action tools require a verified ERC-8004 agent identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`), except the free `gloam_claim` action:

- **Gasless linking (`oak setup link <agentId>`):** If an external wallet owns `<agentId>`, the owner signs a single-use 5-minute EIP-712 `OakIdentityLink` challenge in their own terminal. The owner's private key is never requested, and raw owner signatures are never stored.
- **On-chain registration (`oak setup register`):** Mints a new ERC-8004 NFT to the agent wallet and writes up to 15 user metadata entries plus the mandatory public `oak.registrar = oak` marker in one transaction (needs ETH for gas; `--no-tag` and `tag: false` are refused).
- **Revocation, transfer, burn, or outage:** Run `oak identity unlink` (agent wallet) or `oak identity unlink --owner <linkId>` (NFT owner signature in terminal) to unlink without gas. If the ERC-8004 NFT is transferred or burned, or the link is revoked, action access ends immediately and the add-on clears the saved local `identity` while reads stay open. During a temporary RPC or service outage, the add-on preserves your saved local `identity` and asks you to retry while reads stay open.

---

## 4. Keys and Authority Matrix

Across all of Oak, the **only service-held signing key is the sign-only price signer**; the operator separately holds the single-owner treasury wallet key.

| Party | Holds | Can | Cannot | Worst case if compromised |
| :--- | :--- | :--- | :--- | :--- |
| **One operator owner key** | Single-owner treasury wallet key (`0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`) | Act alone as treasury and contract admin | Spend user wallet balances | One compromised key controls treasury funds and all listed admin powers |
| **Single-owner treasury wallet** (admin and treasury) | Treasury ETH, USDG, and swap, bridge, and partner referral fee income | `OakOracle`: `setPriceSigner` (zero address pauses pricing); `OakBurner`: `armSweep`, `sweepStuck`; convert 25% of fee income to USDG, transfer it to `OakBurner`, and call `buyAndBurn` | Spend user wallet balances; act for a user wallet; re-point oracle pools/token; widen the 50% oracle guard, the 10% burner spot check, or the 5-minute note life | Controls treasury funds and price-signer replacement. The burner refuses notes more than 10% from live spot. Can arm a burner-balance sweep and execute it after 90 days unless a qualifying burn disarms it |
| **Launch wallet** (`0x84b1B9e5D1cAfD9543E684BB39E9cbD478189EE2`) | Pons creator fees (1.7% of trades) and vested team OAK released to it | Claim and transfer the creator-fee recipient; receive vested team OAK; transfer vesting ownership | Accelerate the vesting schedule or withdraw unvested tokens through a deployer role | Controls future creator fees and transferable beneficiary rights in the [team vesting lock](../contracts/deployments/README.md#team-vesting) |
| **Price signer** (the one online key, sign-only) | One sign-only key held by the hosted service; holds no ETH and never sends a transaction | Sign 30-minute `$OAK`-per-ETH price notes (5-minute life, single-use nonce, bound to the calling wallet, the consumer contract `OakBurner`, and the current chain ID). Accepted only within `[spot/2, spot*3/2]` (50% guard) on `OakOracle` and within 10% of live spot on `OakBurner` | Send a transaction; move funds; set a USD value (ETH/USD is read on-chain from `0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca`); replace itself; widen the guard | Until replaced by the treasury wallet: burner chunks are capped at `0.5%` of live pool liquidity (`oracle.liquidityUsdgE6() / 200`) and enforce a 10% live-spot agreement check plus a live-fee output floor |
| **Anyone** (permissionless) | Their own gas | `buyAndBurn()` on `OakBurner` with a valid caller-bound burner note, Pons `createGraduatedPool(token)`, and escrow `claim()` for their own balance | Make a contract accept a note outside the 50% oracle guard or 10% burner check; claim another address's fees; administer contracts | Can move live v4 spot with capital, stalling honest notes while displaced; required capital depends on current liquidity and rebalancing |
| **Oak hosted service** | Sign-only price-signer key; no user wallet key and no NFT owner key | Read chain and project APIs, verify ERC-8004 identities and link challenges, build unsigned transactions and `preview` simulations, issue signed burner price notes | Sign or broadcast a transaction; forge an owner link signature; bypass the on-chain oracle or burner guards | Withhold or falsify API responses, identity status, or price notes |
| **Agent wallets** | Their own key in `~/.oak/wallet.enc` on the user's machine | Control their own funds; register/link/unlink ERC-8004 identity; sign previewed module transactions and enabled recipes after chat confirmation | Control another wallet; administer Oak; use another wallet's price note | That single agent wallet's funds and permissions |
| **Pons owner** (external, `0x263ed295dAFaE1d9AAdD6E56c4B6F9f38eE019Dd`) | External Pons admin key outside Oak's control | Propose a new creator-fee recipient for `$OAK` (`setCreatorFeeRecipient`), executable after a **3-day** public timelock that Oak cannot cancel | Touch Oak's contracts or funds already claimed by the launch wallet | Redirect future `$OAK` creator fees 3 days after a public proposal |

Legacy v1 and v2 billing contracts (`0xF1C5d40997e1151B125a41e822C4278b153c4610` and `0x5e0d93D4bad53388839Ac5A53dB716b70d8606A8`) remain deployed on Robinhood Chain and are unused.

USDG is an external, upgradeable EIP-1967 proxy with issuer freeze authority. Oak's internal review measured implementation `0x68184c449e1a8f34fa18d289737129fd27b66f8f`, but deployment must reread the proxy implementation slot and pin the reviewed implementation code hash. A freeze of `OakBurner` stops burner swaps and sweeps while frozen. Exact-balance checks make incompatible transfer behavior fail closed, but Oak cannot prevent an issuer freeze or proxy upgrade.

---

## 5. Burner Funding and 90-Day Armed Sweep Rule

25% of Oak's income buys back and burns `$OAK`. At least once a month, the operator converts 25% of that period's swap, bridge, and partner referral fee income to USDG, transfers that USDG to `OakBurner` (`0x660b86c5a3f9E1278cB5F01763fd0a630221C18B`) first, fetches a caller-bound `for: "burner"` price note from the hosted service, and calls `buyAndBurn(usdgIn, note, sig)` on `OakBurner` in chunks of at most `oracle.liquidityUsdgE6() / 200` per call (with final `$OAK` output checked against the signed-note minimum below).

The single-owner treasury wallet can arm a sweep of `OakBurner` USDG through a public on-chain transaction (`armSweep`, which records `armedAt` and `armedBalance`) and execute it only after a **90-day timer**. This authority is not mechanically limited to a broken burner. A successful burn cancels the timer when its USDG input is at least `min(ceil(armedBalance / 100), acceptedChunkCap)`, so one permitted maximum chunk can always disarm a working burner; smaller burns leave the timer armed. Calling `sweepStuck()` after 90 days moves **at most the balance recorded when** the timer was armed (`min(balance, armedBalance)`), so later deposits require a fresh 90-day timer.

## 6. Exact On-Chain Burner Checks

[OakBurner.buyAndBurn](../contracts/src/OakBurner.sol) calls `oracle.verifyNote(n, sig, msg.sender)`.
[OakOracle.verifyNote](../contracts/src/OakOracle.sol) enforces `if (n.wallet != boundWallet) revert NoteWrongWallet();`.
A burner note therefore names the caller, not the zero address; nonce consumption is tracked by caller and nonce.
The EIP-712 domain binds the consumer contract and `block.chainid`; the oracle rejects future notes and notes older than 300 seconds.
The oracle accepts a signed OAK-per-ETH value only between `ceil(spot / 2)` and `floor(spot * 3 / 2)`. The burner adds a tighter live check and rejects when `abs(note - spot) > floor(spot / 10)`.
The contracts verify the signed value and its age, not the service's claimed 30-minute OAK averaging method.

[OakPricing.burnerMinOut](../contracts/src/libraries/OakPricing.sol) gives
`Math.mulDiv(usdgIn * decimalScale, oakPerEthE18 * floorBps, ethUsdE18 * 10000)`, where `decimalScale = 10 ** (oakDecimals - 6)`.
For each burn, `floorBps` is derived from the fee frozen at OAK's launch and copied into `launches(poolId)` word 10 at graduation, together with OAK's launch record: `10000 - hookFeeBps - creatorTaxBps - 150`. It is capped at 9607 basis points so it never exceeds the old 49/51 floor, and it may not fall below the documented 9000 basis-point minimum. The hook's global `currentFeePolicy()` applies only to future token launches and cannot change OAK's frozen policy or pool floor. An unreadable, absent, or implausible pool policy, or a missing or mismatched launch record, reverts before swapping.
This is an output floor, not a 2% swap price limit. The first USDG/WETH leg sets `amountOutMinimum: 0`; the final OAK balance delta must meet the combined floor or the transaction reverts. The [fee-policy tests](../contracts/test/OakBurner.t.sol), [fee-margin tests](../contracts/test/RedTeamB.t.sol), and [parity vectors](../contracts/test/vectors.json) exercise these behaviors.

The 0.5% chunk check (`oracle.liquidityUsdgE6() / 200`) uses live, oracle-reported liquidity. Just-in-time (JIT) liquidity can lift its absolute amount; it is not a fixed spending cap.

## Automatic Wallet Creation and Optional Backups

Oak creates a wallet automatically when `oak mcp`, `oak address`, or another wallet command first runs. There are no recovery-word challenges or passphrase prompts. On first run, the agent calls `account`, relays the public address and selected network, asks once whether you want to set a daily spending limit in USD (skipped means no limit), asks you to fund the wallet with a little ETH for gas, and calls `balances` again after you fund it.

The private key stays local in `~/.oak/wallet.enc` (AES-256-GCM, `0600`, inside `~/.oak` at `0700`). A random encryption key is stored in macOS Keychain, Linux persistent Secret Service, or Windows Credential Manager when available. Otherwise Oak saves a random file key in the same owner-only directory (`wallet-key-<id>`, `0600`). This fallback relies on your OS account and filesystem permissions: someone who can read both files can unlock the wallet. No passphrase is requested. Keep only the funds your agent needs.

Later runs reuse the wallet. A corrupt wallet or unavailable existing keychain never creates a replacement. Existing keychain and passphrase wallets keep their format; legacy passphrase wallets still need terminal unlock and cannot run piped MCP.

Backups are optional. When you hold more than pocket change, run `oak export` **in your own terminal, never through the agent** and keep the exported key offline. `oak backup` prints guidance without unlocking or exporting anything. Automatic wallets have no recovery phrase. `oak init --recover` accepts an exported private key or a legacy 24-word phrase, hidden in your terminal; `--replace` preserves the previous encrypted wallet. Oak cannot recover a lost key.

Key data flows from local cryptographic generation to authenticated local storage, then to frozen signing closures in the add-on. Only the public address, signing results and public transaction data cross into MCP/HTTP; raw keys and storage keys are not tool results. Wallets persist until the owner manages their files. Recovery replacement retains old encrypted bytes and the required keychain entry or file key; Oak performs no automatic wallet deletion or key rotation. File fallback encryption does not protect against a reader of the whole Oak directory.
