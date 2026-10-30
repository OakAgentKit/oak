# Codex Setup

Complete the [Shared Prerequisites](README.md#shared-prerequisites-do-this-once) (`oak init`, network config, `oak setup`, and `oak subscribe` once `@oakagentkit/addon` is available at launch) in your own terminal first.

## 1. Add Oak to `~/.codex/config.toml`

Add the `oak` MCP server section to `~/.codex/config.toml`:

```toml
[mcp_servers.oak]
command = "oak"
args = ["mcp"]
```

## 2. Verify in Codex

Start a new Codex session and test a read and a previewed action:

1. **Read test:** *"Call `account`, `balances`, and `positions`."*
2. **Action test (`find_token` → `quote` → `preview` → `swap`):** *"Verify TSLA with `find_token`, quote `10000000` USDG (`10 USDG`) to TSLA with `50` bps slippage, review the `preview` simulation deltas, and run `swap`."*

## Safety & Custody Reminders

- Never invoke `oak init` or `oak export` from inside an agent shell tool call. Run wallet initialization, key export, and external-owner identity link signing exclusively in your own terminal.
- Active subscriptions auto-renew within 3 days of expiry while `oak mcp` is running using local wallet signing and available USDG.
