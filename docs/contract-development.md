# Contract development

The runtime contracts and Oak-authored tests in this repository use MIT. The test-only
legacy oracle in `contracts/test/OakTickMathDifferential.t.sol` is GPL-2.0-or-later,
matching its pinned Uniswap v3 source; it is never deployed. Deployment is an operator action;
no example, test or documentation check broadcasts a deployment automatically.

## Run local checks

Use Node.js 22, Foundry 1.5.1 and Solidity 0.8.26. From the repository root:

```sh
cd contracts
npm install --ignore-scripts --no-audit --no-fund --package-lock=false
forge build --offline
forge test --offline
# Dedicated 100,000-run TickMath differential fuzz profile:
FOUNDRY_PROFILE=tickmath forge test --offline --match-contract OakTickMathDifferentialTest
# Opt-in exact sweep of all 1,774,545 valid ticks:
OAK_TICKMATH_EXHAUSTIVE=true forge test --offline \
  --gas-limit 10000000000 \
  --match-test test_ExhaustiveDomainMatchesReferenceAndIsStrictlyMonotonic
```

The package manifest pins OpenZeppelin 5.4.0 and the forge-std commit. Offline
Foundry commands need the compiler already installed. Alternatively pass
`--use /path/to/solc-0.8.26`. The public CI provisions its checksum-pinned compiler.
The default profile fixes `fuzz.runs` at 256; the dedicated `tickmath` profile fixes
it at 100,000. The exhaustive check is intentionally opt-in and reports skipped
without `OAK_TICKMATH_EXHAUSTIVE=true`; its documented local gas limit accommodates
all 1,774,545 iterations in one test transaction.
Fork/RPC-gated tests remain skipped without their explicit inputs; local tests do
not verify a live deployment. See [review summaries](reviews.md).

## Rehearse deployment

1. Copy [deploy.env.sample](../deploy.env.sample) to an ignored local `.env` and supply the public addresses and launch parameters. The sample intentionally has no key field.
2. Run the build and tests above. Load the public configuration locally.
3. Simulate `LaunchOakToken` if a token launch is required, then `DeployOracle`, `DeployBurner` and `DeploySubscription` in that order:

```sh
forge script script/DeployOracle.s.sol:DeployOracle --rpc-url "$OAK_RPC_URL"
```

Use the matching script and contract name for each step. Without `--broadcast`,
this rehearses the calls. Check the chain, immutable addresses, token decimals,
signer, payees, predecessor and previews; record each address for the next step.
Only the human operator selects a local keystore or hardware signer and repeats
an approved command with `--broadcast`. Never put a private key or recovery words
in `.env`, arguments, an agent prompt or logs.

The [deployment JSON files](../contracts/deployments/README.md) are placeholders
until an operator records verified receipts. Read [authority and custody](security.md)
before deployment, and preserve those disclosures when proposing changes.
