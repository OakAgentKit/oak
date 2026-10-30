# Security, Custody, and Authority

The treasury and contract admin is the single-owner wallet `0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`. One owner key can spend treasury funds, redirect future subscription payments, replace the price signer, and retire subscriptions. There is no second-signature requirement. Key compromise exposes these powers; key loss can make treasury funds and administration inaccessible. It cannot spend user wallet balances. Safe support is an optional deployment profile, not the launch setup.

---

## 1. Reporting a Vulnerability

Do not report security vulnerabilities in public GitHub issues, pull requests, or public channels on X.

Use **GitHub private vulnerability reporting** on the official OakAgentKit repository:

- **Report URL:** https://github.com/OakAgentKit/oak/security/advisories/new

Include in your report:

1. The affected surface (local CLI/MCP add-on, 25 ecosystem connectors, smart contracts in `contracts/`, hosted service, or deployed contracts on Robinhood Chain `4663`).
2. Minimal reproduction steps, proof-of-concept test or Foundry test (`forge test`), and the exact commit SHA or package version.
3. The concrete impact against the authority boundaries documented below.

We acknowledge private advisory submissions within **48 hours**, provide a triage assessment within **7 days**, and coordinate remediation and public disclosure once a fix or contract migration is verified. Good-faith security research on local forks or testnet (`46630`) without disrupting production services or third-party users is welcomed under safe harbor.

---

## 2. Where Your Key Lives (Local Self-Custody)

Oak is built so that **your private key never leaves your computer** and **the hosted Oak service never sees your key and never signs or sends a transaction**: **your swaps and deposits go straight from your wallet to the project, and subscription payments go to the burner (`OakBurner`) and the single-owner treasury wallet**.

- **Owner-run terminal boundary (`oak init` & `oak export`):** Both commands require an interactive terminal (`isTTY`) and must be run **in your own terminal, never through the agent**. Even if an agent can allocate a pseudo-terminal (`PTY`), running `oak init` and `oak export` yourself keeps your 24 recovery words and private key out of agent prompts, tool outputs, and logs. **Oak cannot recover a lost key.**
- **Encryption at rest (`~/.oak/wallet.enc`):** Your 32-byte secp256k1 private key is encrypted with `AES-256-GCM` inside `~/.oak/wallet.enc` (file mode `0600`, directory mode `0700`; symlinks and hardlinks are rejected). By default, the 32-byte data encryption key is stored in your persistent OS keychain (macOS Keychain, Windows Credential Manager, or Linux Secret Service). If no persistent keychain is available, Oak derives the key in memory from your terminal passphrase (`>= 12` characters) via `scrypt` (`N = 131072, r = 8, p = 1`).
- **Argument redaction:** Both the local MCP bridge and the hosted service reject any tool argument containing `private_key`, `secret_key`, `wallet_key`, `mnemonic`, `seed`, `seed_phrase`, or `recovery_phrase`.
- **Pre-sign simulation (`preview`) & auto-renewal signing:** Before signing any action tool transaction, the local bridge runs `preview` (`eth_simulateV1` with `traceTransfers: true`), reuses a matching same-block preview within 12 seconds, builds exact token approvals (`amountIn`, never unlimited), checks ETH gas headroom, and records the in-flight transaction in a local per-wallet journal (`~/.oak/<address>.pending.json`) for crash recovery. While `oak mcp` is running, active subscriptions automatically renew within 3 days of expiry using local wallet signing and available USDG (cancel any time with `oak cancel`).

---

## 3. ERC-8004 Identity Verification & Unlinking

Read tools (`find_token`, `balances`, `price`, `quote`, `preview`, `history`, `positions`, `account`, and module reads) work without an identity or subscription. Action tools require a verified ERC-8004 agent identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`) plus an active subscription:

- **Gasless linking (`oak setup link <agentId>`):** If an external wallet owns `<agentId>`, the owner signs a single-use 5-minute EIP-712 `OakIdentityLink` challenge in their own terminal. The owner's private key is never requested, and raw owner signatures are never stored.
- **On-chain registration (`oak setup register [--no-tag]`):** Mints a new ERC-8004 NFT to the agent wallet (needs ETH for gas).
- **Revocation, transfer, burn, or outage:** Run `oak identity unlink` (agent wallet) or `oak identity unlink --owner <linkId>` (NFT owner signature in terminal) to unlink without gas. If the ERC-8004 NFT is transferred or burned, or the link is revoked, action access ends immediately and the add-on clears the saved local `identity` while reads stay open. During a temporary RPC or service outage, the add-on preserves your saved local `identity` and asks you to retry while reads stay open.

---

## 4. Keys and Authority Matrix

Across all of Oak, the **only service-held signing key is the sign-only price signer**; the operator separately holds the single-owner treasury wallet key.

| Party | Holds | Can | Cannot | Worst case if compromised |
| :--- | :--- | :--- | :--- | :--- |
| **One operator owner key** | Single-owner treasury wallet key (`0x856bb126188bDB5e425D3ac9D59E9ffBD12e6ECf`) | Act alone as treasury and contract admin | Spend user wallet balances | One compromised key controls treasury funds and all listed admin powers |
| **Single-owner treasury wallet** (admin, treasury, Pons creator-fee recipient) | Treasury ETH and USDG already paid to it (75% of subscription payments); claimed `$OAK` creator fees (1.7% of Pons trades) | `OakSubscription`: `setPayees`, `retire`, `setGrandfatherRoot`; `OakOracle`: `setPriceSigner` (zero address pauses pricing); `OakBurner`: `armSweep`, `sweepStuck`; Pons: claim and transfer `$OAK` creator-fee recipient | Change wallet paid time or counts; spend user wallet balances; reverse past payments; act for a user wallet; re-point oracle pools/token; widen the 50% guard or 5-minute note life | Controls treasury funds, future payout destinations, and creator-fee recipient. Can misprice sign-ups and burner chunks within the same `0.5x–1.5x` guard band as a stolen price signer. Can sweep stuck burner USDG only after the 90-day armed timer |
| **Price signer** (the one online key, sign-only) | One sign-only key held by the hosted service; holds no ETH and never sends a transaction | Sign 30-minute `$OAK`-per-ETH price notes (5-minute life, single-use nonce, bound to the calling wallet (including burner callers), the consumer contract and the current chain ID). Accepted only within `[spot/2, spot*3/2]` (50% guard) | Send a transaction; move funds; change paid time, counts, or records; set a USD value (ETH/USD is read on-chain from `0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca`); replace itself; widen the guard | Until replaced by the treasury wallet: new holder sign-ups and no-hold sign-ups/renewals use notes at `0.5x–1.5x` of spot OAK-per-ETH; USD-per-OAK moves inversely and the entry curve also affects the resulting count (existing records never change; holder renewals need no note); burner chunks (capped at `0.5%` of live pool liquidity, or lifted via JIT liquidity) can accept less OAK than honest pricing would imply; the 49/51 output factor adds to the signer-band exposure |
| **Anyone** (permissionless) | Their own gas | `buyAndBurn()` on `OakBurner` with a valid burner note, `sweepToTreasury()`, Pons `createGraduatedPool(token)`, and escrow `claim()` for their own balance | Make a contract accept a note outside the 50% guard; claim another address's fees; administer contracts | Can move live v4 spot with capital, stalling honest notes while displaced; required capital depends on current liquidity and arbitrage |
| **Oak hosted service** | Sign-only price-signer key; no user wallet key and no NFT owner key | Read chain and project APIs, verify ERC-8004 identities and link challenges, build unsigned transactions and `preview` simulations, issue signed price notes | Sign or broadcast a transaction; forge an owner link signature; bypass the on-chain 50% guard | Withhold or falsify API responses, identity status, or price notes; holder renewals and `oak cancel` work on-chain without the service |
| **Agent wallets** | Their own key in `~/.oak/wallet.enc` on the user's machine | Control their own funds; register/link/unlink ERC-8004 identity; subscribe, renew, cancel; sign previewed module transactions and enabled recipes | Control another wallet; administer Oak; use another wallet's price note | That single agent wallet's funds and permissions |
| **Pons owner** (external, `0x263ed295dAFaE1d9AAdD6E56c4B6F9f38eE019Dd`) | External Pons admin key outside Oak's control | Propose a new creator-fee recipient for `$OAK` (`setCreatorFeeRecipient`), executable after a **3-day** public timelock that Oak cannot cancel | Touch Oak's contracts or funds already claimed by the treasury wallet | Redirect future `$OAK` creator fees 3 days after a public proposal |

Holder-plan renewal is payment-safe: both `renew()` and `renewWithAuthorization()` check that the wallet still holds at least its recorded post-burn `signupOakCount` before collecting USDG. A shortfall reverts with `InsufficientOak(balance, required)`, leaving paid time and payment state unchanged. The [allowance](../contracts/test/OakSubscription.t.sol#L388) and [authorization](../contracts/test/OakSubscription.t.sol#L406) regression tests cover both paths; [no-hold renewal](../contracts/test/OakSubscription.t.sol#L454) has no OAK-balance requirement.

---

## 5. Burner 90-Day Armed Sweep Rule

Every subscription payment splits in the same transaction: **25% to `OakBurner`** and **75% to the single-owner treasury wallet**. Anyone can call permissionless `buyAndBurn(usdgIn, note, sig)` on `OakBurner` to buy and burn `$OAK` (input limited to `oracle.liquidityUsdgE6() / 200` per call, with final OAK output checked against the signed-note minimum below).

The single-owner treasury wallet can sweep stuck USDG from `OakBurner` only after a **90-day timer** started by a public on-chain transaction (`armSweep`, which records `armedAt` and `armedBalance`). **Any successful burn cancels** the timer. Calling `sweepStuck()` after 90 days moves **at most the balance recorded when** the timer was armed (`min(balance, armedBalance)`), so later deposits require a fresh 90-day timer.

## 6. Exact On-Chain Burner Checks

[OakBurner.buyAndBurn](../contracts/src/OakBurner.sol) calls `oracle.verifyNote(n, sig, msg.sender)`.
[OakOracle.verifyNote](../contracts/src/OakOracle.sol) enforces `if (n.wallet != boundWallet) revert NoteWrongWallet();`.
A burner note therefore names the caller, not the zero address; nonce consumption is tracked by caller and nonce.
The EIP-712 domain binds the consumer contract and `block.chainid`; the oracle rejects future notes and notes older than 300 seconds.
The signed OAK-per-ETH value must be between `ceil(spot / 2)` and `floor(spot * 3 / 2)`.
The contract verifies the signed value and its age, not the service's claimed 30-minute OAK averaging method.

[OakPricing.burnerMinOut](../contracts/src/libraries/OakPricing.sol) returns
`Math.mulDiv(usdgIn * decimalScale, oakPerEthE18 * 49, ethUsdE18 * 51)`, where `decimalScale = 10 ** (oakDecimals - 6)`.
This rounds down a minimum of 49/51 (about 96.0784%) of the note-implied fair OAK output, allowing about 3.9216% less output before rounding.
Its source comment says: "49/51 = 96.0784%: accommodates hook/creator fees plus bounded route impact."
This is an output floor, not a 2% swap price limit. The first USDG/WETH leg sets `amountOutMinimum: 0`; the final OAK balance delta must meet the combined floor or the transaction reverts.
At the low end of the accepted signer band, this floor can be about 48.0392% of spot-implied fair output (about 51.9608% less), before rounding and ETH/USD average-versus-spot differences.
The [fee-margin and zero-wallet tests](../contracts/test/RedTeamB.t.sol) and [parity vectors](../contracts/test/vectors.json) exercise these behaviors.

The 0.5% chunk check uses live, oracle-reported liquidity. Just-in-time (JIT) liquidity can lift its absolute amount; it is not a fixed spending cap.
Payment splitting uses `burn = amount / 4` (rounded down in USDG base units), with the remainder sent to treasury.
The on-chain oracle latches graduation; it does not enforce a 30-minute OAK history window. The service's warmup policy supplies that wait.

## Automatic Wallet Creation and Optional Backups

Oak creates a wallet automatically when `oak mcp`, `oak address`, or another wallet command first runs. There are no recovery-word challenges or passphrase prompts. The agent calls `account`, relays the public address and selected network, asks you to fund it with a little ETH for gas and USDG, then calls `balances` again after you fund it.

The private key stays local in `~/.oak/wallet.enc` (AES-256-GCM, `0600`, inside `~/.oak` at `0700`). A random encryption key is stored in macOS Keychain, Linux persistent Secret Service, or Windows Credential Manager when available. Otherwise Oak saves a random file key in the same owner-only directory (`wallet-key-<id>`, `0600`). This fallback relies on your OS account and filesystem permissions: someone who can read both files can unlock the wallet. No passphrase is requested. Keep only the funds your agent needs.

Later runs reuse the wallet. A corrupt wallet or unavailable existing keychain never creates a replacement. Existing keychain and passphrase wallets keep their format; legacy passphrase wallets still need terminal unlock and cannot run piped MCP.

Backups are optional. When you hold more than pocket change, run `oak export` **in your own terminal, never through the agent** and keep the exported key offline. `oak backup` prints guidance without unlocking or exporting anything. Automatic wallets have no recovery phrase. `oak init --recover` accepts an exported private key or a legacy 24-word phrase, hidden in your terminal; `--replace` preserves the previous encrypted wallet. Oak cannot recover a lost key.

Key data flows from local cryptographic generation to authenticated local storage, then to frozen signing closures in the add-on. Only the public address, signing results and public transaction data cross into MCP/HTTP; raw keys and storage keys are not tool results. Wallets persist until the owner manages their files. Recovery replacement retains old encrypted bytes and the required keychain entry or file key; Oak performs no automatic wallet deletion or key rotation. File fallback encryption does not protect against a reader of the whole Oak directory.
