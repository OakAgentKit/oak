# Generic MCP Client Setup (Grok, Custom Hosts & CLI)

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks once whether you want a daily spending limit in USD, asks you to fund the wallet address with ETH on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, chat confirmation and optional backup guidance.

---

## 1. Connect Any `stdio` MCP Host

Configure Grok or any Model Context Protocol `stdio` client to spawn:

```text
command: oak
args: ["mcp"]
```

Or in standard MCP JSON format:

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

---

## 2. Direct CLI Tool Invocation (`oak call`)

You can also invoke read tools directly from a script or terminal via `oak call <tool> '<json>'`:

```bash
# Check wallet address, network, ERC-8004 identity status, and optional daily spending limit
oak status

# One-call portfolio reads
oak call balances '{}'
oak call positions '{}'

# Read-only token lookup and quote on mainnet (4663)
oak call find_token '{"query":"TSLA"}'
oak call quote '{"from":"USDG","to":"TSLA","amountIn":"10000000","slippageBps":50}'

# For signing, use an MCP client: calling a listed action tool or oak_prepare gives the six-part summary and actionId,
# and oak_execute with actionId signs after you say yes in chat.
```

---

The CLI can read and prepare quotes. Use a connected MCP client to prepare an action (by calling a listed action tool or `oak_prepare` with `{"name": "<tool>", "arguments": {...}}`), review the six-part summary and `actionId` in chat, and reply yes so the agent calls `oak_execute` with `{"actionId": "<actionId>"}`. Placeholder transaction arrays are not executable commands.

## 3. Troubleshooting & Recovery Reference

Every error message in Oak is a plain sentence naming the cause and the exact command to fix it:

| Message | Cause | Exact Fix |
| :--- | :--- | :--- |
| `run this in your own terminal, not through the agent` | `oak init` or `oak export` was invoked without an interactive TTY. | Run `oak init` or `oak export` directly in your own system terminal. |
| `Actions are paused until this wallet has an Oak identity (a one-time public on-chain profile). Registering costs a small ETH network fee and needs the person's OK. Run oak setup register, or oak setup link <agentId> for an existing ID. Reads still work.` / `Actions are paused until this wallet has an Oak identity (a one-time public on-chain profile). Registering costs a small ETH network fee and needs the person's OK. Call oak_setup {"mode":"register"}, or oak_setup {"mode":"link","agentId":"…"} for an existing ID. Reads still work.` | Action tool called before setting up an ERC-8004 identity. The second form is what a client sees when the `oak_setup` tool is available. | Run `oak setup link <agentId>` (no ETH) or `oak setup register` (needs ETH), or call `oak_setup`. |
| `Identity changed, expired or link revoked. Run oak setup link <agentId> with the current owner to verify or link it again. Reads remain available; actions are paused.` | The linked ERC-8004 NFT was transferred or burned, or the link was revoked. Local `identity` was cleared. | Run `oak setup link <agentId>` with the current NFT owner, or register a new ID with `oak setup register`. |
| `Identity status is unavailable. Please try again. Reads remain available; actions are paused.` | Temporary RPC or service outage prevented identity verification. Local `identity` is preserved. | Keep your config and retry once reachable; read tools remain open. |
| `OAK_NETWORK disagrees with the local config; set the network in the config explicitly.` | Environment variables and `~/.oak/config.json` specify different networks (`4663` vs `46630`). | Align `OAK_NETWORK`, `OAK_CHAIN_ID`, and `OAK_RPC_URL` in `~/.oak/config.json`. |
| `This swap goes through KyberSwap or Velora, and Oak can only approve those routes on a connection that can trace transactions. This one can't, so nothing was signed and no approval was sent. Ask for a new quote; Oak will offer a Uniswap route. To use KyberSwap or Velora, set OAK_RPC_URL to a Robinhood Chain RPC that supports debug_traceCall and restart Oak.` | KyberSwap and Velora routes need an RPC that supports `debug_traceCall` with `callTracer` (and `prestateTracer` when an approval comes first). Oak's default public Robinhood Chain RPC did not offer these methods when checked on 2026-11-04. Oak refuses these routes before signing; other routes, including Uniswap, still work. | Ask for a new `quote` to swap through Uniswap now, or run `oak config set OAK_RPC_URL <tracing-rpc-url>` with a Robinhood Chain (`4663`) endpoint that supports tracing, then restart Oak. Run `oak config check-rpc` (no wallet needed, changes nothing, never prints the URL) to see whether the RPC Oak would use supports `callTracer` and `prestateTracer`; it exits `0` only when both answer. `OAK_CENSUS_RPC_URL` does not add tracing. |
| `Sending needs a connection that can check each step of the transaction, and this one can't, so nothing was signed. To enable it, set OAK_RPC_URL to a Robinhood Chain RPC that supports debug_traceCall and restart Oak. Oak plans to provide one.` | `send` requires `debug_traceCall` with `callTracer` on Robinhood Chain for every recipient, and the current RPC does not support it. | Run `oak config set OAK_RPC_URL <tracing-rpc-url>` with a Robinhood Chain (`4663`) endpoint that supports `debug_traceCall` (`callTracer`), verify with `oak config check-rpc`, and restart Oak. |
| `needs ETH for network fees: need at least <needed> wei including transaction value; held <held> wei. Send ETH to <address> on chain <chainId>. Approximately <needed in ETH> ETH needed; <held in ETH> ETH held.` | Wallet ETH cannot cover `value + gas * maxFeePerGas` (with 25% gas headroom). | Send native ETH on the named chain to `oak address` and retry. |
| `Wallet journal is unresolved; wait for the pending transaction before a new action.` | An in-flight transaction in `~/.oak/<address>.pending.json` has not yet been reconciled. | Start `oak mcp` to reconcile or fee-bump the pending transaction. |

## Confirmation and current access

Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action).
Before signing an action, the agent prepares it (with a listed action tool or `oak_prepare`) and shows the six-part summary, `actionId`, and UTC expiry in chat; saying yes runs `oak_execute` with `{"actionId": "<actionId>"}`, which re-simulates, checks terms and your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
