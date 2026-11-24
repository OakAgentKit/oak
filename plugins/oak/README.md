# Oak for Claude Code

Connect a local Oak MCP server with tools for 37 projects on Robinhood Chain.
Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. The plugin runs
`npx -y @oakagentkit/addon@0.4.2 mcp`; a global Oak install is optional.

In Claude Code:

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

Restart Claude Code after installing. Check `/mcp` for `plugin:oak:oak`.
If you previously added Oak manually, remove that duplicate MCP entry first.

First use creates a wallet on your computer. Ask for `account` and show only the
public address and network. On first run, the agent asks once whether you want a
daily spending limit in USD (`oak_spending_limit`). Fund ETH for network fees when ready.
Oak has no subscription; reads are free, and some actions carry an Oak fee, always shown before you say yes. Most reads need no identity; Roots Report requires a registered Oak agent, and actions require a verified
ERC-8004 identity (except the free `gloam_claim` action). Identity registration
and transactions require your yes in chat before local signing. Never run `oak init`
or `oak export` through an agent, or paste a key into chat. Oak cannot recover a
lost key. Oak is not affiliated with Robinhood; availability varies by region.

See [setup](https://github.com/OakAgentKit/oak/blob/main/docs/client-setup/README.md)
and [security](https://github.com/OakAgentKit/oak/blob/main/docs/security.md).

The plugin wrapper is MIT licensed; the npm add-on has its own package terms.

**Roots Report (`roots_report`):** Ask your agent to check a coin before you buy. It reads who bought in the first 30 seconds, who funded the creator and early buyers, linked wallets, whether the coin's own pool gives a price to sell it, the sell fee, the creator's share, how holdings are spread and who holds the liquidity, each with a reference point. It gives facts and context, never a verdict or advice, and says plainly what it couldn't check. Free for registered Oak agents.

**Acorn Audits (`acorn_request`):** Your agent can prepare a request for a Sapling Review ($49 per scan, up to 1,000 lines) or a Heartwood Audit (from $299, quoted). Send it to support@oakagentkit.org or message @OakAgentKit on X. Built by Oak Agent Kit.

For “launch a coin”, offer FOBO first. Oak prepares the action and asks for a yes in chat before signing.
