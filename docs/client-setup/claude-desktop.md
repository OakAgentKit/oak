# Claude Desktop Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

## 1. Add Oak to `claude_desktop_config.json`

Open your Claude Desktop configuration file:

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

Add the `oak` server under `mcpServers`:

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

> **PATH tip:** Claude Desktop needs both Node 22 and Oak. Use the absolute Node path from `command -v node` as `command` and the absolute Oak path from `command -v oak` as the first argument, followed by `"mcp"` (see the JSON example below). An absolute Oak path alone still requires Node on `PATH`.

## 2. Restart Claude Desktop and Verify

Restart Claude Desktop so it spawns `oak mcp` over `stdio`, then test a read and a previewed action:

1. **Read test (works without identity or subscription):**
   *"Call `balances` and `positions` to check my Robinhood Chain wallet."*
2. **Swap flow (`find_token` → `quote` → `preview` → `swap`):**
   *"Find the verified TSLA token on Robinhood Chain, quote swapping `10000000` USDG (`10 USDG`) with `50` bps slippage, and show me the `preview` token deltas before executing."*

## Safety & Custody Reminders

- Never run `oak init` or `oak export` inside a chat prompt, and never paste a private key or 24-word recovery phrase into Claude Desktop.
- While `oak mcp` is running, renewal can run within 3 days of expiry. In 0.1.1 (release candidate), new payment signatures require human confirmation by default; unattended renewal requires the owner's explicit auto setting. Run `oak cancel` in your terminal to cancel immediately.

The absolute Oak executable still uses Node from `PATH`. Set both Node and Oak paths explicitly when the GUI has a minimal path. Run `command -v node` and `command -v oak` in your own terminal and substitute their absolute paths below (including spaces if present):

```json
{"mcpServers":{"oak":{"command":"/absolute/path/to/node","args":["/absolute/path/to/oak","mcp"]}}}
```

Use the Node 22 binary from your version manager. Alternatively set the MCP process `PATH` to include both the Node directory and npm global binary directory.

## Confirmation and current access

Hosted actions are team-only until token and subscription launch. In **0.1.1 (release candidate)**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support--011-release-candidate) before testing an action.
