# Gemini CLI Setup

Complete the [Shared Prerequisites](README.md#shared-prerequisites-do-this-once) (`oak init`, network config, `oak setup`, and `oak subscribe` once `@oakagentkit/addon` is available at launch) in your own terminal first.

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
- Active subscriptions auto-renew within 3 days of expiry while `oak mcp` is running using local wallet signing and available USDG.
