# Oak documentation

Start with [What is Oak?](what-is-oak.md): a plain-English introduction and your first five minutes.

## Connect and explore

- [Connect your AI app](client-setup/README.md): install Oak, create the wallet automatically, and choose a client.
- [Examples](../examples/README.md): three runnable examples with offline fixtures by default.
- [37 configured projects](robinhood-chain-projects.md): capabilities grouped by use.
- [Tool reference](mcp-tools-reference.md): names, inputs, network scope and which tools `tools/list` shows. Find any other tool with `find_tool` and run it with `run_tool`.

## Understand access and custody

- [Access and pricing](access-and-pricing.md): no-subscription access, ERC-8004 identity setup, optional daily spending limit, and swap, bridge, send, Morpho bundle, optional Clanker LP reward share, and partner referral fees.
- [Security](security.md): chat confirmation, local checks, custody, authority and private reporting.
- [Headless wallets](headless-wallet.md): key storage, legacy wallets and the optional daily spending limit.
- [Review summaries](reviews.md): what was reviewed and what remains unmeasured.

## Build and contribute

- [Contract development](contract-development.md): dependencies, local checks and deployment rehearsal.
- [Invariants](INVARIANTS.md): contract properties and test references.
- [Contributing](../CONTRIBUTING.md): docs, examples, contracts and declarative recipes.
- [Changelog](../CHANGELOG.md): release history.

Core and add-on 0.4.1 are published on npm; Oak has no subscription, reads are free, and hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action). See the [live deployments and team vesting lock](../contracts/deployments/README.md).

## Playbook-supported projects

**Autonomo:** Oak gets an agent the USDG dollars it pays with, an on-chain identity, and small top-ups of the separate wallet Autonomo's own tools pay from, with a yes for each action. Autonomo's own team runs it; Oak didn't build it and doesn't run it. Read `oak_playbook {"name":"autonomo"}` (MCP resource `oak://agent-playbooks/autonomo.md`). This playbook uses existing funding, identity and send tools; it adds no module or tools. Never export or share the Oak wallet key for Autonomo.

Version 0.4.1 bundles 53 playbooks. The 37 tool-backed projects and callable catalog are unchanged.
