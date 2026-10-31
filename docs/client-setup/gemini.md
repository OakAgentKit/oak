# Gemini CLI Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

## 1. Add Oak to `~/.gemini/settings.json`

Edit `~/.gemini/settings.json` and register `oak` under `mcpServers`:

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

## 2. Verify in Gemini

Launch Gemini and test:

1. **Read test:** *"Run `balances` and `positions` on my Oak wallet."*
2. **Action test (`find_token` → `quote` → `preview` → `swap`):** *"Find the verified TSLA token via `find_token`, quote `10000000` USDG (`10 USDG`) to TSLA (`slippageBps: 50`), show the `preview` transfer deltas, and execute `swap`."*

## Safety & Custody Reminders

- Run `oak init`, `oak export`, and external-owner `oak setup link <agentId>` only in your own system terminal, never through an agent shell command.
- Renewal can run within 3 days of expiry while `oak mcp` is running. Since 0.1.1, new payment signatures require human confirmation by default; unattended renewal requires the owner's explicit auto setting.

## Confirmation and current access

Hosted actions are team-only until token and subscription launch. Since **0.1.1**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
