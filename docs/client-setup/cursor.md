# Cursor Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

## 1. Configure `.cursor/mcp.json`

Add Oak to your workspace `.cursor/mcp.json` (or global `~/.cursor/mcp.json`):

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

## 2. Reload MCP Servers and Verify

Open **Cursor Settings → MCP**, confirm `oak` shows as green/connected (exposing 100 tools on mainnet `4663`, or 14 tools on testnet `46630`), and test in Cursor Agent mode:

1. **Read test:** *"Run `balances` and `positions` to inspect my Robinhood Chain portfolio."*
2. **Action test:** *"Use `find_token` to verify TSLA, `quote` `10000000` USDG (`10 USDG`) to TSLA at `50` bps slippage, and show the `preview` before calling `swap`."*

## Safety & Custody Reminders

- Always run `oak init`, `oak export`, and owner-signed `oak setup link <agentId>` in your own external terminal, never through Cursor's integrated agent terminal.
- Active subscriptions auto-renew within 3 days of expiry while `oak mcp` is running using local wallet signing and available USDG.
