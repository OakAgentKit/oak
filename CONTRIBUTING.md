# Contributing to Oak Agent Kit

Small fixes are welcome: a clearer sentence, a reproducible bug or a useful example is a good first contribution. Describe the problem and what your change improves.

Oak Agent Kit uses a split public/private model:

- **Open source in this repository ([MIT](LICENSE)):** Documentation (`docs/`), runnable examples (`examples/`), and smart contracts (`contracts/`). Recipes are separate opt-in packages.
- **Published npm packages ([`LICENSE-PACKAGES.md`](LICENSE-PACKAGES.md)):** `@oakagentkit/addon` and `@oakagentkit/core` are published on npm as compiled packages under a free-to-use, no-copying license. Their TypeScript source is private.
- **Hosted service (private):** The Oak hosted service (which reads chain and project APIs, verifies ERC-8004 identities and subscription access, runs transaction previews, and issues signed price notes) is private and closed source.

---

## 1. Ways to Contribute

### Documentation & Client Setup (`docs/`)

- Fix broken links, clarify MCP client configuration in [`docs/client-setup/`](docs/client-setup/), or improve project notes in [`docs/robinhood-chain-projects.md`](docs/robinhood-chain-projects.md) and [`docs/mcp-tools-reference.md`](docs/mcp-tools-reference.md).
- Keep all examples strictly factual. Never add token hype, promised returns, or affiliation claims.
- Preserve required partner attributions (`Powered by Merkl — https://app.merkl.xyz` on Merkl tools and HeyResearch attribution on HeyResearch tools).

### Runnable Examples (`examples/`)

- Examples must consume the published `@oakagentkit/addon` package or standard MCP `stdio` calls (`oak mcp` / `oak call`) and never rely on private internal files.
- Always pass token amounts as **decimal base-unit strings** (for example, `"10000000"` for `10 USDG` with 6 decimals; `"1000000000000000000"` for `1 ETH` with 18 decimals), never floating-point numbers.
- Never commit private keys, recovery phrases, keystores, `.env` files, or keyed RPC URLs. Use `.env.example` placeholders only.

### Smart Contracts (`contracts/`)

Requires **Foundry (`forge`) `1.5.1`** (`Solidity ^0.8.26`).

```bash
cd contracts
npm install --ignore-scripts --no-audit --no-fund --package-lock=false
forge test --offline
```

Contract contribution rules:

1. **Shared rounding vectors:** `OakPricing.sol` must pass all shared entry-curve, holder-count, 5% sign-up burn, and 25/75 payment-split vectors in `contracts/test/vectors.json`.
2. **Fork testing hygiene:** When running local Anvil forks of Robinhood Chain (`4663`) or Testnet (`46630`), start Anvil with `--accounts 0` and verify fresh test wallets have `eth_getCode == 0x` and nonce `0` (Anvil default accounts carry inherited EIP-7702 delegation code on both networks).
3. **Authority disclosures:** Any contract change must keep the authority table in [`docs/security.md`](docs/security.md) accurate.

---

## 2. Publishing Declarative Project Recipes (`oak-recipe/v1`)

Ecosystem builders on Robinhood Chain (`4663`) can publish standalone declarative recipes without modifying `@oakagentkit/core`. Users opt in via `oak recipes add <pkg-or-path>`.

```json
{
  "schema": "oak-recipe/v1",
  "project": "my-project",
  "name": "stake",
  "description": "Stake exact token base units into the vault",
  "chainId": 4663,
  "contract": "0x1111111111111111111111111111111111111111",
  "function": {
    "type": "function",
    "name": "stake",
    "stateMutability": "nonpayable",
    "inputs": [{ "name": "amount", "type": "uint256" }],
    "outputs": []
  },
  "inputs": [
    { "name": "amount", "type": "uint256", "description": "Token base units (18 decimals)" }
  ],
  "kind": "tx",
  "approve": {
    "token": "0x2222222222222222222222222222222222222222",
    "amountFromInput": "amount"
  }
}
```

### Recipe Package Rules

- **Schema & types:** `schema` must be `"oak-recipe/v1"`, `chainId` must be `4663`, addresses must be EIP-55 checksummed, `project` and `name` must match `^[a-z0-9-]{1,40}$`, and `inputs` must match `function.inputs` by position and type.
- **Data-only npm archive layout:** Place recipes at `package/recipes/<name>.recipe.json` (each `<= 64 KiB`) and declare `"oakProject": "<project>"` in `package/package.json` (`<= 64 KiB`). The decompressed archive must not exceed `4 MiB` or `100` entries and must contain only regular files and directories (no symlinks, hardlinks, or PAX/GNU extensions).
- **Zero code execution:** `oak recipes add` streams the archive and copies only validated `.recipe.json` files into `~/.oak/recipes/<project>/`. It ignores `.js` files and `package.json` lifecycle scripts and never runs `npm install` or `require()`.
- **Labelling:** All imported recipes are opt-in and labelled **`as-is, not reviewed by Oak`**.

---

## 3. Security & Conduct

- Do not open public issues for security vulnerabilities. Report vulnerabilities privately via [GitHub Security Advisories](https://github.com/OakAgentKit/oak/security/advisories/new) as described in [`docs/security.md`](docs/security.md).
- All contributors follow our [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

For full compiler prerequisites, see [contract development](docs/contract-development.md).
Documentation changes should keep relative links working and name the version that introduces a behavior.
Examples use fixtures by default; include the commands you ran and any checks you could not run.
