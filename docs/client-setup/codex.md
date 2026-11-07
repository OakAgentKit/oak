# Codex Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

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
2. **Action test (`find_token` → `quote` → `swap` (prepare) → chat yes → `oak_execute`):** *"Verify TSLA with `find_token`, quote `10000000` USDG (`10 USDG`) to TSLA with `50` bps slippage, prepare `swap`, show its summary, `actionId` and expiry, and wait for my yes before `oak_execute`."*

## Safety & Custody Reminders

- Never invoke `oak init` or `oak export` from inside an agent shell tool call. Run wallet initialization, key export, and external-owner identity link signing exclusively in your own terminal.
- Every action prepares a six-part summary and asks for your yes or no in chat (calling a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes) before signing locally.

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
