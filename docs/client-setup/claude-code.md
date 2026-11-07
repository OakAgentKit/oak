# Claude Code Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

## Plugin shortcut

Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. These shortcuts run
`npx -y @oakagentkit/addon@0.3.0 mcp`, so no global Oak install is needed.
Review your app’s install confirmation, then start a fresh session. If you already
configured Oak manually, use that connection or remove it before adding a second one.
Installing connects tools; identity registration and transactions still need
your yes in chat.

In Claude Code, run these two commands:

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

Restart Claude Code, then check `/mcp` for `plugin:oak:oak`. On Claude Code
2.1.292 or later, the shell shortcut is `claude plugin install oak --marketplace OakAgentKit/oak`.

## 1. Register the MCP Server

Run the following command in your terminal:

```bash
claude mcp add oak -- oak mcp
```

Or add `oak` to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "oak": {
      "command": "oak",
      "args": ["mcp"]
    }
  }
}
```

## 2. Verify the Connection

Check that `oak` is listed and connected in Claude Code:

```bash
claude mcp list
```

Then run a first read or action inside Claude Code:

- **Read:** *"Check my `account` status, `balances`, and active `positions`."*
- **Action (`find_token` → `quote` → `swap` (prepare) → chat yes → `oak_execute`):** *"Look up TSLA with `find_token`, get a `quote` for `10000000` USDG (`10 USDG`), prepare the `swap`, show its summary, `actionId` and expiry, and wait for my yes before `oak_execute`."*

## Safety & Custody Reminders

- **Never allow Claude Code's Bash tool to run `oak init` or `oak export`.** Even though an agent with shell access can allocate a pseudo-terminal (`PTY`), `oak init`, `oak export`, and external-owner `oak setup link <agentId>` signing must be run by you directly in your own system terminal so recovery words and keys never enter agent context or logs.
- Every action prepares a six-part summary and asks for your yes or no in chat (calling a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes) before signing locally.

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
