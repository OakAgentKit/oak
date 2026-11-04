# Oak for Claude Code

Connect a local Oak MCP server with tools for 28 projects on Robinhood Chain.
Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. The plugin runs
`npx -y @oakagentkit/addon@0.2.4 mcp`; a global Oak install is optional.

In Claude Code:

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

Restart Claude Code after installing. Check `/mcp` for `plugin:oak:oak`.
If you previously added Oak manually, remove that duplicate MCP entry first.

First use creates a wallet on your computer. Ask for `account` and show only the
public address and network. Fund ETH for network fees and USDG only when ready.
Read tools need no identity or subscription; actions require a verified identity
and paid subscription. Registration and payments require separate approval.
By default you approve transactions before local signing. Never run `oak init`
or `oak export` through an agent, or paste a key into chat. Oak cannot recover a
lost key. Oak is independent of Robinhood; availability varies by region.

See [setup](https://github.com/OakAgentKit/oak/blob/main/docs/client-setup/README.md)
and [security](https://github.com/OakAgentKit/oak/blob/main/docs/security.md).

The plugin wrapper is MIT licensed; the npm add-on has its own package terms.
