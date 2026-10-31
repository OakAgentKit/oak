# Claude Code Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

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
- Renewal can run within 3 days of expiry while `oak mcp` is running. Since 0.1.1, new payment signatures require human confirmation by default; unattended renewal requires the owner's explicit auto setting.

## Confirmation and current access

Hosted actions are team-only until token and subscription launch. Since **0.1.1**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
