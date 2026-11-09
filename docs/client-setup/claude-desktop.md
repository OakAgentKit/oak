# Claude Desktop Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

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

1. **Read test (works without an identity):**
   *"Call `balances` and `positions` to check my Robinhood Chain wallet."*
2. **Swap flow (`find_token` → `quote` → `swap` (prepare) → chat yes → `oak_execute`):**
   *"Find the verified TSLA token on Robinhood Chain, quote swapping `10000000` USDG (`10 USDG`) with `50` bps slippage, prepare `swap`, show its summary, `actionId` and expiry, and wait for my yes before `oak_execute`."*

## Safety & Custody Reminders

- Never run `oak init` or `oak export` inside a chat prompt, and never paste a private key or 24-word recovery phrase into Claude Desktop.
- Every action prepares a six-part summary and asks for your yes or no in chat (calling a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes) before signing locally.

The absolute Oak executable still uses Node from `PATH`. Set both Node and Oak paths explicitly when the GUI has a minimal path. Run `command -v node` and `command -v oak` in your own terminal and substitute their absolute paths below (including spaces if present):

```json
{"mcpServers":{"oak":{"command":"/absolute/path/to/node","args":["/absolute/path/to/oak","mcp"]}}}
```

Use the Node 22 binary from your version manager. Alternatively set the MCP process `PATH` to include both the Node directory and npm global binary directory.

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) and [per-client MCP tool annotations](README.md#per-client-mcp-tool-annotations-and-approval-prompts) (`readOnlyHint: true` on `oak_prepare`, `destructiveHint: true` on `oak_execute`; clicking `Always allow` in Claude Desktop skips future pre-tool prompts in that workspace while chat confirmation remains required) before testing an action.
