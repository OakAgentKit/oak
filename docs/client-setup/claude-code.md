# Claude Code Setup

Complete the [Shared Prerequisites](README.md#shared-prerequisites-do-this-once) (`oak init`, network config, `oak setup`, and `oak subscribe` once `@oakagentkit/addon` is available at launch) in your own terminal first.

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
- **Action (`find_token` → `quote` → `preview` → `swap`):** *"Look up TSLA with `find_token`, get a `quote` for `10000000` USDG (`10 USDG`), inspect the `preview`, and execute the `swap`."*

## Safety & Custody Reminders

- **Never allow Claude Code's Bash tool to run `oak init` or `oak export`.** Even though an agent with shell access can allocate a pseudo-terminal (`PTY`), `oak init`, `oak export`, and external-owner `oak setup link <agentId>` signing must be run by you directly in your own system terminal so recovery words and keys never enter agent context or logs.
- Active subscriptions auto-renew within 3 days of expiry while `oak mcp` is running using local wallet signing and available USDG.
