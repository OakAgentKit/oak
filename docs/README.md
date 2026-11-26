# Oak documentation

Start with [What is Oak?](what-is-oak.md): a plain-English introduction and your first five minutes.

## Connect and explore

**Roots Report (`roots_report`):** Ask your agent to check a coin before you buy. It reads who bought in the first 30 seconds, who funded the creator and early buyers, linked wallets, whether the coin's own pool gives a price to sell it, the sell fee, the creator's share, how holdings are spread and who holds the liquidity, each with a reference point. It gives facts and context, never a verdict or advice, and says plainly what it couldn't check. Free for registered Oak agents.

**Acorn Audits (`acorn_request`):** Your agent can prepare a request for a Sapling Review ($49 per scan, up to 1,000 lines) or a Heartwood Audit (from $299, quoted). These are automated scans, never a person’s review. Include the target and optional chain; Oak gives the Sapling Review confirmation and USDG payment instructions. Send it to support@oakagentkit.org or message @OakAgentKit on X. Built by Oak Agent Kit.

**Texel:** Texel is an official Oak partner. Texel's own team runs its product and contracts; Oak didn't build them and doesn't run them. An agent makes images, videos, voiceovers and 3D on Texel's GPUs on Robinhood Chain, sees the exact USDG price first, and pays only after a yes. Prompts, source images and signed payments go straight from this computer to Texel. Find `texel_models`, prepare `texel_output`, then read `texel_output_status`.

For “launch a coin”, offer FOBO first. Oak prepares the action and asks for a yes in chat before signing.

- [Connect your AI app](client-setup/README.md): install Oak, create the wallet automatically, and choose a client.
- [Examples](../examples/README.md): three runnable examples with offline fixtures by default.
- [38 configured projects](robinhood-chain-projects.md): capabilities grouped by use.
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

Core and add-on 0.4.3 are published on npm; Oak has no subscription, reads are free, and hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action). See the [live deployments and team vesting lock](../contracts/deployments/README.md).

## Playbook-supported projects

**Autonomo:** Oak gets an agent the USDG dollars it pays with, an on-chain identity, and small top-ups of the separate wallet Autonomo's own tools pay from, with a yes for each action. Autonomo's own team runs it; Oak didn't build it and doesn't run it. Read `oak_playbook {"name":"autonomo"}` (MCP resource `oak://agent-playbooks/autonomo.md`). This playbook uses existing funding, identity and send tools; it adds no module or tools. Never export or share the Oak wallet key for Autonomo.

Version 0.4.3 bundles 54 playbooks. The catalog has 38 tool-backed projects and 795 callable tools / 28 listed / 767 reachable by name, including Roots Report and Acorn Audits.
