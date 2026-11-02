# Cursor Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

## Quick connection

Requires Node.js 22 (`>=22.12.0 <23`) and npm on your PATH. These shortcuts run
`npx -y @oakagentkit/addon@0.2.0 mcp`, so no global Oak install is needed.
Review your app’s install confirmation, then start a fresh session. If you already
configured Oak manually, use that connection or remove it before adding a second one.
Installing connects tools; identity registration and paid subscriptions still need
separate approval.

[Add to Cursor](https://cursor.com/install-mcp?name=oak&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBvYWthZ2VudGtpdC9hZGRvbkAwLjIuMCIsIm1jcCJdfQ%3D%3D) · [Install in VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522oak%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540oakagentkit%252Faddon%25400.2.0%2522%252C%2522mcp%2522%255D%257D)

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

Open **Cursor Settings → MCP**, confirm `oak` shows as green/connected (in version 0.2.0, listing 84 tools on mainnet `4663`, or 19 tools on testnet `46630`; the full catalogs have 659 and 39 tools via the finders), and test in Cursor Agent mode:

1. **Read test:** *"Run `balances` and `positions` to inspect my Robinhood Chain portfolio."*
2. **Action test:** *"Use `find_token` to verify TSLA, `quote` `10000000` USDG (`10 USDG`) to TSLA at `50` bps slippage, and show the `preview` before calling `swap`."*

## Safety & Custody Reminders

- Always run `oak init`, `oak export`, and owner-signed `oak setup link <agentId>` in your own external terminal, never through Cursor's integrated agent terminal.
- Renewal can run within 3 days of expiry while `oak mcp` is running. Since 0.1.1, new payment signatures require human confirmation by default; unattended renewal requires the owner's explicit auto setting.

## Confirmation and current access

Hosted actions require a verified ERC-8004 identity and an active subscription in 0.2.0 paid mode. Since **0.1.1**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
