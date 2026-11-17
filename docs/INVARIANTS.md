# Contract Invariants

These rules describe the revised contract source, including burner fixes that are not deployed yet. The deployed contracts were built from the reviewed source; see the [deployment record](../contracts/deployments/README.md).

- Each burner price-note nonce is single-use for its caller ([burner nonce test](../contracts/test/OakBurner.t.sol#L493)).
- Every burner note is bound to `msg.sender` (`if (n.wallet != boundWallet) revert NoteWrongWallet()`), is within 300 seconds, and is within 10% of live OAK/ETH spot before any swap, and its OAK output floor uses the higher of the note price and live spot, re-derived from the WETH actually received. Its fee allowance uses the fee frozen at OAK's launch and copied into `launches(poolId)` word 10 at graduation, plus the immutable creator tax and a 150 basis-point impact allowance. The fee allowance multiplier stays between 9000 and 9607 basis points; changing the hook's global default for future token launches cannot change it.
- Each `buyAndBurn(usdgIn, note, sig)` call spends USDG already held by `OakBurner`, up to the lower of `oracle.liquidityUsdgE6() / 200` (0.5% of live pool USDG liquidity) and 250 USDG.
- The USDG-to-WETH leg must deliver at least 99.5% of the WETH implied by the 30-minute ETH/USD average. This bound can still accept a lagging average.
- `OakBurner` calls `oak.burn()` on the bought OAK, lowering `totalSupply`; it does not send the OAK to `0x000000000000000000000000000000000000dEaD`.
- Burns depend on caller-bound price notes from Oak's server. Since the Oak 0.3.10 server release (2026-11-16), burner notes are issued only to the operator wallet, with no permissionless fallback.
- The owner address (`safe`) sets the price signer on `OakOracle`. Setting it to zero pauses every note-based action, such as burns; setting a nonzero signer restores note verification.
- OAK must have 18 decimals. Tokens other than USDG sent to `OakBurner` cannot be recovered.
- The owner address can arm a sweep with 90 days of notice. Only a burn spending at least 1% of the armed balance, rounded up, or consuming the armed remainder disarms it; smaller burns reduce that remainder. A sweep pays at most the armed balance not yet burned, bounded by the current USDG balance; later deposits do not replenish its allowance.
- A sweep is void if the price signer changes after arming, and anyone can flag that change. The owner address must arm a fresh notice to recover funds after invalidation ([sweep tests](../contracts/test/OakBurner.t.sol)).
- Oracle construction and deployment require the OAK launch record to exist and match the native pair, fee 0, tick spacing 200, and pinned current Pons hook. Construction also requires an 18-decimal token0 and 6-decimal token1 in the ETH/USDG pool, and a readable PoolManager `extsload(bytes32(0))` response; a zero word is allowed.
- `phase()` reads Pons before the READY latch. Unknown or unreadable Pons data fails closed even after graduation has latched.
- A transfer to `0x000000000000000000000000000000000000dEaD` leaves `totalSupply` unchanged; `supplyNet()` reads `totalSupply` without subtracting that address's balance.
- `OakTickMath.sqrtRatioAtTick` equals the test-only Uniswap v3 reference and is strictly increasing across adjacent valid ticks; deterministic bounds, bit-transition and 1,000-tick-stride checks, a 100,000-run fuzz profile, and an opt-in exhaustive sweep cover the claim ([differential test](../contracts/test/OakTickMathDifferential.t.sol)).
- Reads are free, and some actions carry an Oak fee, always shown before you say yes.
