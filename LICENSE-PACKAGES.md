# Oak Agent Kit — npm Package License Summary (DRAFT)

> **STATUS: DRAFT** — Plain-English summary of the license terms for the published `@oakagentkit/addon` and `@oakagentkit/core` npm packages. Final legal text will be published in the npm package archives and updated here at launch.

---

## 1. Repository Split: What Is MIT vs. What Is Covered Here

Oak Agent Kit separates open repository material from the compiled npm packages and the hosted service:

| Surface | License | Summary |
| :--- | :--- | :--- |
| **This GitHub Repository** (`docs/`, `examples/`, `recipes/`, `contracts/`) | **[MIT License](LICENSE)** | Free to read, fork, modify, test, and reuse under standard MIT terms. |
| **Published npm Packages** (`@oakagentkit/addon`, `@oakagentkit/core`) | **Oak Package License (Free to Use, No Copying — DRAFT)** | Free to install and run; no copying, redistribution, or extraction of the compiled add-on or connectors. |
| **Oak Hosted Service** | **Proprietary (Private)** | Closed-source hosted service. Access requires a verified ERC-8004 agent identity and an active on-chain subscription for action tools. |

---

## 2. Plain-English Summary of the npm Package Terms

### What You Can Do (Free to Use)

1. **Install and run:** Download and install `@oakagentkit/addon` (and its dependency `@oakagentkit/core`) from the official npm registry on your machines at no licensing cost.
2. **Operate AI agents:** Run `oak init`, `oak setup`, `oak subscribe`, `oak mcp`, and `oak call` to manage local agent wallets and interact with Robinhood Chain (`4663`) and Testnet (`46630`) for personal or commercial use.
3. **Build and share examples or recipes:** Write, publish, and distribute your own examples, agent prompts, and declarative `oak-recipe/v1` JSON recipes that invoke `@oakagentkit/addon` as an external dependency.

### What You Cannot Do (No Copying)

1. **No redistribution or rehosting:** You may not copy, republish, mirror, sublicense, sell, or redistribute the `@oakagentkit/addon` or `@oakagentkit/core` packages or their compiled code outside standard npm installation on your own systems.
2. **No extraction or derivative SDKs:** You may not extract, bundle, or repurpose Oak's 25 ecosystem connectors, transaction-building logic, or MCP bridge into a competing package, SDK, or hosted service.
3. **No reverse engineering:** Except to the extent such restrictions are prohibited by applicable law, you may not decompile, disassemble, or reconstruct the private source code of `@oakagentkit/addon` or `@oakagentkit/core`.

---

## 3. Third-Party Open-Source Dependencies

The published npm packages declare runtime dependencies on third-party open-source packages (such as `viem`, `@modelcontextprotocol/sdk`, `@noble/*`, `@scure/*`, and `ajv`). Those third-party packages remain governed by their respective permissive open-source licenses (`MIT`, `Apache-2.0`, `ISC`, `BSD-2-Clause`, and `BSD-3-Clause`).

---

## 4. Disclaimers

- **Provided "AS IS":** The npm packages are provided without warranty of any kind, express or implied.
- **Access only, no safety checks:** Oak adds no spending caps, allowlists, or safety checks of its own. You and your agent are responsible for inspecting every `preview` simulation before signing.
- **No promised returns & non-affiliation:** Oak never promises returns, does not provide financial advice, and is not affiliated with Robinhood. You are responsible for complying with the laws and third-party terms in your jurisdiction.
