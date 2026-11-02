# Oak for AI agents

This file is the entry point for AI agents using Oak or working in this repository.
It points to the documents that hold each rule; those documents are authoritative.

## Using Oak

- **Setup:** follow [Connect your agent](docs/client-setup/README.md). Its copy-paste setup prompt is the expected first run.
- **Tools and conventions:** [MCP tools reference](docs/mcp-tools-reference.md) lists every tool and the shared conventions, such as decimal base-unit amount strings and chain IDs.
- **Projects:** [Robinhood Chain projects](docs/robinhood-chain-projects.md) describes what each of the 25 integrations can do.
- **Custody and confirmation:** [Security, custody and authority](docs/security.md) is the custody rulebook. Never ask for keys or recovery words, never read wallet or key files, and never run `oak init`, `oak export` or `oak config set confirm auto` on the owner's behalf.
- **Access:** [Access and pricing](docs/access-and-pricing.md) explains plans; get the owner's approval before identity registration or a subscription payment.

## Working in this repository

- Contributor workflow, checks and review expectations: [CONTRIBUTING.md](CONTRIBUTING.md).
- Contracts are Foundry projects under [contracts/](contracts/); see [Contract setup](docs/contract-development.md).
- Examples are Node.js 22 under [examples/](examples/README.md); their tests use fixture data and do not send real transactions.
- Report vulnerabilities privately through [SECURITY.md](SECURITY.md), never in a public issue.
