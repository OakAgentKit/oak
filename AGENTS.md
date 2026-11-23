# Oak for AI agents

This file is the entry point for AI agents using Oak or working in this repository.
It points to the documents that hold each rule; those documents are authoritative.

## Using Oak

- **Setup:** follow [Connect your agent](docs/client-setup/README.md). Its copy-paste setup prompt is the expected first run.
- **Tools and conventions:** [MCP tools reference](docs/mcp-tools-reference.md) lists every tool and the shared conventions, such as decimal base-unit amount strings and chain IDs.
- **Projects:** [Robinhood Chain projects](docs/robinhood-chain-projects.md) describes what each of the 37 projects, including Agent Wormhole (signed token metadata snapshots, request-time verdicts, and offline text scans; none proves safety or sellability) can do.
- **Custody and confirmation:** [Security, custody and authority](docs/security.md) is the custody rulebook. Never ask for keys or recovery words, never read wallet or key files, and never run `oak init` or `oak export` on the owner's behalf.
- **Access and fees:** [Access and pricing](docs/access-and-pricing.md) explains no-subscription access, ERC-8004 identity setup, the optional daily spending limit in USD, and Oak's swap, bridge, send, Morpho bundle, optional Clanker LP reward share, and partner referral fees; get the owner's yes in chat before identity registration or any transaction.

## Playbook-supported projects

- **Autonomo:** Oak gets an agent the USDG dollars it pays with, an on-chain identity, and small top-ups of the separate wallet Autonomo's own tools pay from, with a yes for each action. Autonomo's own team runs it; Oak didn't build it and doesn't run it. Read `oak_playbook {"name":"autonomo"}` (MCP resource `oak://agent-playbooks/autonomo.md`). This playbook uses existing funding, identity and send tools; it adds no module or tools. Never export or share the Oak wallet key for Autonomo.

Version 0.4.1 bundles 53 playbooks; playbook support adds no tool-backed project to the 37-project catalog.

## Working in this repository

- Contributor workflow, checks and review expectations: [CONTRIBUTING.md](CONTRIBUTING.md).
- Contracts are Foundry projects under [contracts/](contracts/); see [Contract setup](docs/contract-development.md).
- Examples are Node.js 22 under [examples/](examples/README.md); their tests use fixture data and do not send real transactions.
- Report vulnerabilities privately through [SECURITY.md](SECURITY.md), never in a public issue.
