# Oak for Claude Code

Connect a local Oak MCP server with tools for 35 projects on Robinhood Chain.
Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. The plugin runs
`npx -y @oakagentkit/addon@0.3.5 mcp`; a global Oak install is optional.

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
Oak is free to use: read tools need no identity, and actions require a verified
ERC-8004 identity (except the free `gloam_claim` action). Identity registration
and transactions require your yes in chat before local signing. Never run `oak init`
or `oak export` through an agent, or paste a key into chat. Oak cannot recover a
lost key. Oak is not affiliated with Robinhood; availability varies by region.

See [setup](https://github.com/OakAgentKit/oak/blob/main/docs/client-setup/README.md)
and [security](https://github.com/OakAgentKit/oak/blob/main/docs/security.md).

The plugin wrapper is MIT licensed; the npm add-on has its own package terms.
