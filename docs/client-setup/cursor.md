# Cursor Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

## Quick connection

Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. These shortcuts run
`npx -y @oakagentkit/addon@0.3.0 mcp`, so no global Oak install is needed.
Review your app’s install confirmation, then start a fresh session. If you already
configured Oak manually, use that connection or remove it before adding a second one.
Installing connects tools; identity registration and transactions still need
your yes in chat.

[Add to Cursor](https://cursor.com/install-mcp?name=oak&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBvYWthZ2VudGtpdC9hZGRvbkAwLjMuMCIsIm1jcCJdfQ%3D%3D) · [Install in VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522oak%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540oakagentkit%252Faddon%25400.3.0%2522%252C%2522mcp%2522%255D%257D)

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

Open **Cursor Settings → MCP**, confirm `oak` shows as green/connected (in version 0.3.0, listing 23 tools on mainnet `4663`, or 17 tools on testnet `46630`; the full catalogs have 737 and 50 tools via the finders), and test in Cursor Agent mode:

1. **Read test:** *"Run `balances` and `positions` to inspect my Robinhood Chain portfolio."*
2. **Action test:** *"Use `find_token` to verify TSLA, `quote` `10000000` USDG (`10 USDG`) to TSLA at `50` bps slippage, prepare `swap`, show its summary, `actionId` and expiry, and wait for my yes before `oak_execute`."*

## Safety & Custody Reminders

- Always run `oak init`, `oak export`, and owner-signed `oak setup link <agentId>` in your own external terminal, never through Cursor's integrated agent terminal.
- Every action prepares a six-part summary and asks for your yes or no in chat (calling a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes) before signing locally.

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
