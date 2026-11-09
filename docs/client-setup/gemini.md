# Gemini CLI Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

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
2. **Action test (`find_token` → `quote` → `swap` (prepare) → chat yes → `oak_execute`):** *"Find the verified TSLA token via `find_token`, quote `10000000` USDG (`10 USDG`) to TSLA (`slippageBps: 50`), prepare `swap`, show its summary, `actionId` and expiry, and wait for my yes before `oak_execute`."*

## Safety & Custody Reminders

- Run `oak init`, `oak export`, and external-owner `oak setup link <agentId>` only in your own system terminal, never through an agent shell command.
- Every action prepares a six-part summary and asks for your yes or no in chat (calling a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes) before signing locally.

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) and [per-client MCP tool annotations](README.md#per-client-mcp-tool-annotations-and-approval-prompts) (`readOnlyHint: true` on `oak_prepare`, `destructiveHint: true` on `oak_execute`; `--yolo` or `"trust": true` in `~/.gemini/settings.json` skips Gemini CLI's pre-tool prompt while chat confirmation remains required) before testing an action.
