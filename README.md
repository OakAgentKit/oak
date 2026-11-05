![Oak Agent Kit: an oak tree with glowing roots and a figure carrying a lantern](assets/oak-cover.webp)

# Oak Agent Kit

Oak connects your AI agent to **31 projects on Robinhood Chain** through one
local MCP server. Your agent can check balances, compare swap routes, manage
vault and lending positions, bridge assets, and use project tools from the same
connection. MCP is the standard that lets an AI app call external tools.

Oak creates a wallet on your computer. The hosted service supplies quotes,
prices and unsigned transactions; the add-on checks, signs and sends locally.
By default, you review and confirm each action before signing.
Oak is independent and is not affiliated with Robinhood.

[![npm](https://img.shields.io/npm/v/@oakagentkit/addon?label=%40oakagentkit%2Faddon&color=062F27)](https://www.npmjs.com/package/@oakagentkit/addon)
[![License: MIT](https://img.shields.io/badge/license-MIT-062F27)](LICENSE)

**Prepared release: 0.2.6**, with publication pending for `@oakagentkit/core` and
`@oakagentkit/addon`, plus the optional `@oakagentkit/gloam` engine. See the [changelog](CHANGELOG.md) for the fixes in this release.
Mainnet paid access uses the existing [0.2.0 deployment](contracts/deployments/README.md).

[Website](https://oakagentkit.org) · [Setup guides](docs/client-setup/README.md) ·
[Tool reference](docs/mcp-tools-reference.md) · [Security](docs/security.md) ·
[Plans and fees](https://oakagentkit.org/pricing.html)

## Install

You need Node.js **22.12.0 or newer**, npm and an MCP client.
Run these commands in your terminal:

```sh
npm i -g @oakagentkit/addon@0.2.6
oak --version
```

The prepared version is 0.2.6. Publication is pending;
wait for the release before running the pinned install command.

## Connect your agent

Choose the instructions for your app, then start a fresh session.
If Oak is already connected, keep that connection or remove it before adding
another. Connecting tools does not authorize identity registration or payments.

### Claude Code

After the global install, run:

```sh
claude mcp add oak -- oak mcp
claude mcp list
```

Alternatively, use the [Claude Code plugin](docs/client-setup/claude-code.md):

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

The plugin runs `npx -y @oakagentkit/addon@0.2.6 mcp`; it does not need a global
Oak install. Restart Claude Code and check `/mcp` for `plugin:oak:oak`.

### Codex

Add this section to `~/.codex/config.toml` after the global install:

```toml
[mcp_servers.oak]
command = "oak"
args = ["mcp"]
```

Start a new session and ask for `account` and `balances`.
[Full Codex guide](docs/client-setup/codex.md)

### Cursor

After the global install, add Oak in **Cursor Settings → MCP**, using this
configuration in `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "oak": { "command": "oak", "args": ["mcp"] }
  }
}
```

[Add to Cursor](https://cursor.com/install-mcp?name=oak&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBvYWthZ2VudGtpdC9hZGRvbkAwLjIuNiIsIm1jcCJdfQ%3D%3D) · [Install in VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522oak%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540oakagentkit%252Faddon%25400.2.6%2522%252C%2522mcp%2522%255D%257D)

These shortcuts run the pinned 0.2.6 package through `npx`.
[Cursor guide](docs/client-setup/cursor.md) ·
[Claude Desktop](docs/client-setup/claude-desktop.md) ·
[Other clients](docs/client-setup/generic-mcp.md)

### First use

Ask your agent:

> Call account and tell me my public wallet address and network. Then check
> balances and positions. Explain any unavailable service results.

Oak creates the wallet automatically on first use. Fund the returned address
with ETH for network fees and USDG for subscriptions, then re-check `balances`.
Reads work without an identity or subscription. Actions require a verified
ERC-8004 identity and an active subscription. Approve public identity
registration and subscription payments separately; registration costs ETH gas.
Linking an existing identity is gasless. An external owner signs the link in
their own terminal. [Setup and access](docs/client-setup/README.md)

## What your agent can do

| Task | Projects on Robinhood Chain mainnet |
| --- | --- |
| Swap, trade, launch tokens and manage liquidity | KyberSwap, Velora, Pons, pools.trade, Clanker, Hookr, TickerSpring, Uniswap liquidity (v3/v4) |
| Pay privately | Gloam (optional local engine) |
| Use vaults and claim rewards | Steakhouse, Spark, NetNet, Longbow, Grove, Beefy, Merkl, Chop |
| Supply collateral, lend, borrow and repay | Morpho Blue, Priors, LayerBank, Borro |
| Buy, sell and redeem principal tokens | Pendle |
| Bridge assets | Relay |
| Use prediction markets, funding data and research | Meridian, Lighter, HeyResearch, Wormhole (Agent Wormhole) |
| Manage identity, names, locks and AI credits | ERC-8004, hood.ag, HoodLock, Orbio |

`earn_options` compares LayerBank and Pendle through a read-only helper.
It is excluded from the project count.

The catalog has **700 mainnet tools** and **42 testnet tools**. Your agent sees
105 everyday tools on mainnet, or 22 on testnet, in `tools/list`. It can find and
run the rest through `find_tool` and `run_tool`.
The [tool reference](docs/mcp-tools-reference.md) lists every tool and its inputs.
The [project guide](docs/robinhood-chain-projects.md) explains each integration.

For example, ask your agent to compare swap routes and show the preview before
signing, list vault positions, or find a project's available tools.
Actions depend on project availability, permissions and access checks. The
catalog is not a guarantee that every action is available to every wallet or
validated end to end.

Mainnet is chain **4663**. Testnet **46630** has basic and identity tools, without
swap routes or the other ecosystem modules. Token amounts use decimal base-unit
strings: `"10000000"` is 10 USDG with 6 decimals.

Merkl tools: Powered by Merkl, [app.merkl.xyz](https://app.merkl.xyz).
HeyResearch reads run on request and retain attribution and citations.
Gloam is an official Oak partner. Gloam's own team runs its product and contracts; Oak didn't build them and doesn't run them. Borro is an official Oak partner. Borro's own team runs its product and contracts; Oak didn't build them and doesn't run them. Oak x Chop. Chop's own team runs its product and contracts; Oak didn't build them and doesn't run them. Agent Wormhole is an official Oak partner. Agent Wormhole's own team runs its product and contracts; Oak didn't build them and doesn't run them. Agent Wormhole checks signed token metadata snapshots and request-time verdicts on chain 4663 and scans supplied text offline; neither read proves safety or sellability.

[![OakAgentKit on HEY Research Lab](https://heyresearch.xyz/api/badge/oakagentkit)](https://heyresearch.xyz/project/oakagentkit?utm_source=badge&utm_medium=readme)

## Plans and fees

Installing the npm packages is free under their [package license](LICENSE-PACKAGES.md).
Read tools need no identity or subscription. Hosted actions require both.
Call `account` for the launch phase and indicative subscription price.

| Plan | Cost per 30 days | Requirement |
| --- | --- | --- |
| Holder | 9 USDG | Hold the quoted entry count of OAK at sign-up. The transaction burns 5% of that count, rounded up; keep the recorded remainder for access. Renewals burn nothing. |
| No-hold | 9 USDG plus one sixth of the entry price | No OAK holding requirement. The cost is 12.333333 USDG at the $20 entry floor and is repriced at renewal after warmup. |

During the launch curve, only no-hold is open, at 12.333333 USDG per 30 days.
After graduation, both plans wait for 30 minutes of pool history. Then the holder
plan opens and no-hold follows the entry-price calculation.
Holding OAK buys access and nothing else.

Payments split in the same transaction: 25% goes to `OakBurner` and 75% to the
single-owner treasury. Oak adds no per-call or trade fee. ETH gas and project
fees are separate. Prepayment is capped at 90 days ahead.

While `oak mcp` runs, it checks renewal on startup and hourly; renewal is
available with three days or less remaining. New payment signatures require
human confirmation by default. Cancelling ends access immediately and forfeits
remaining paid days. [Full plan and renewal terms](docs/access-and-pricing.md) ·
[Website pricing](https://oakagentkit.org/pricing.html)

<a id="before-anything-signs"></a>

## Security model

Your key stays on your computer. The server never receives it and never signs
or sends a transaction. Swaps and deposits go straight from your wallet to the
project; subscriptions go to the burner and treasury.

Before signing, Oak checks routes, recipients, approval spenders and simulated
wallet outflows. It refuses unlimited and incremental approvals, unsupported
permits and blanket operator approvals. Uniswap v4 liquidity adds allow up to 0.5% headroom (rounded up to the next base unit) within caller caps to tolerate small price ticks; unused ETH is refunded in the same transaction. A finite capped approval can leave an allowance that needs
cleanup; Oak makes no unconditional zero-residual-allowance promise.

Human confirmation is on by default. Declining, timing out or having no supported
confirmation form stops signing. A connected tool list alone does not prove
your client supports action confirmation. The owner can select auto mode in
their own terminal; its automatic approval budget defaults to 50 USD per local
calendar day. Actions above the remaining budget, without a fresh USD value or
with unavailable usage records require human approval. That budget does not cap
spending a person explicitly approves. Oak sets no operator token allowlist.

Previews estimate transfers; they do not prove sellability or off-chain
settlement such as Relay destination fills or Meridian relayer execution.
Gas is separate. Your computer, RPC and external projects remain trust
boundaries. There is no completed third-party audit.

One owner key controls treasury funds and contract administration, including
future subscription payment routing, the price signer and subscription
retirement. There is no second-signature requirement. Compromise exposes those
powers; loss can make funds and administration inaccessible. It cannot spend
user wallet balances. [Authority details](docs/security.md#4-keys-and-authority-matrix)

Never give an agent keys or recovery words. Never let an agent run `oak init` or
`oak export`; those commands belong in your own terminal. Backups are optional:
`oak backup` gives guidance. Oak cannot recover a lost key. Oak shows a region
notice by default; the operator and user are responsible for local compliance.
[Security and custody](docs/security.md)

## Source and links

This repository contains MIT-licensed docs, examples and contracts.
The compiled npm packages have their [own license](LICENSE-PACKAGES.md);
their implementation source and the hosted service are private.
Contract source, tests, ABIs and deployment scripts are in [contracts/](contracts/).
The [deployment record](contracts/deployments/README.md) lists live addresses.
The [offline examples](examples/README.md) run with fixture data.

[What is Oak?](docs/what-is-oak.md) · [Examples](examples/README.md) ·
[Contract setup](docs/contract-development.md) · [Changelog](CHANGELOG.md) ·
[Contributing](CONTRIBUTING.md) · [Code of Conduct](CODE_OF_CONDUCT.md) ·
[Report a vulnerability](SECURITY.md) · [Website](https://oakagentkit.org) ·
[@OakAgentKit](https://x.com/OakAgentKit)


Gloam is opt-in. Install its optional engine beside the add-on to use private USDG payments:

```sh
npx -y -p @oakagentkit/addon@0.2.6 -p @oakagentkit/gloam@0.2.6 oak mcp
```

The default MCP command keeps the add-on alone. Gloam tools remain discoverable without the engine and give this install command when called. Only shield deposits sign wallet transactions. Pay, claim and cash-out make proofs locally for Gloam's relay; every action requires human confirmation, including free claims. Never paste a note or key into an agent. Back up Gloam notes with `oak export` in your own terminal; backups cover only the notes present when made.
