# Generic MCP Client Setup (Grok, Custom Hosts & CLI)

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

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
# Check subscription status, $OAK held vs required, launch phase, and indicative no-hold price
oak status

# One-call portfolio reads
oak call balances '{}'
oak call positions '{}'

# Read-only token lookup and quote on mainnet (4663)
oak call find_token '{"query":"TSLA"}'
oak call quote '{"from":"USDG","to":"TSLA","amountIn":"10000000","slippageBps":50}'

# For signing, use an MCP client that supports form elicitation.
# oak call has no confirmation form; ask mode refuses action signatures.
```

---

The CLI can read and prepare quotes, but its lack of a confirmation form means
it cannot sign actions in default ask mode. Use a compatible MCP client to
request a fresh quote, inspect the preview and confirm each signature. Placeholder
transaction arrays are not executable commands.

## 3. Troubleshooting & Recovery Reference

Every error message in Oak is a plain sentence naming the cause and the exact command to fix it:

| Message | Cause | Exact Fix |
| :--- | :--- | :--- |
| `run this in your own terminal, not through the agent` | `oak init` or `oak export` was invoked without an interactive TTY. | Run `oak init` or `oak export` directly in your own system terminal. |
| `Actions are paused until this wallet has an Oak identity (a one-time public on-chain profile). Registering costs a small ETH network fee and needs the person's OK. Run oak setup register, or oak setup link <agentId> for an existing ID. Reads still work.` / `Actions are paused until this wallet has an Oak identity (a one-time public on-chain profile). Registering costs a small ETH network fee and needs the person's OK. Call oak_setup {"mode":"register"}, or oak_setup {"mode":"link","agentId":"…"} for an existing ID. Reads still work.` | Action tool called before setting up an ERC-8004 identity. The second form is what a client sees when the `oak_setup` tool is available. | Run `oak setup link <agentId>` (no ETH) or `oak setup register` (needs ETH), or call `oak_setup`. |
| `Identity changed, expired or link revoked. Run oak setup link <agentId> with the current owner to verify or link it again. Reads remain available; actions are paused.` | The linked ERC-8004 NFT was transferred or burned, or the link was revoked. Local `identity` was cleared. | Run `oak setup link <agentId>` with the current NFT owner, or register a new ID with `oak setup register`. |
| `Identity status is unavailable. Please try again. Reads remain available; actions are paused.` | Temporary RPC or service outage prevented identity verification. Local `identity` is preserved. | Keep your config and retry once reachable; read tools remain open. |
| `OAK_NETWORK disagrees with the local config; set the network in the config explicitly.` | Environment variables and `~/.oak/config.json` specify different networks (`4663` vs `46630`). | Align `OAK_NETWORK`, `OAK_CHAIN_ID`, and `OAK_RPC_URL` in `~/.oak/config.json`. |
| `This swap route goes through KyberSwap or Velora, and Oak can only approve it on a connection that can trace transactions step by step. Your current connection can't. …Nothing was signed.` | KyberSwap and Velora routes need an RPC that supports `debug_traceCall` with `callTracer` (and `prestateTracer` when an approval comes first). Oak's default public Robinhood Chain RPC did not offer these methods when checked on 2026-11-04. Oak refuses these routes before signing; other routes, including Uniswap, still work. | Swap through Uniswap now, or run `oak config set OAK_RPC_URL <tracing-rpc-url>` with a Robinhood Chain (`4663`) endpoint that supports tracing, then restart Oak. Run `oak config check-rpc` (no wallet needed, changes nothing, never prints the URL) to see whether the RPC Oak would use supports `callTracer` and `prestateTracer`; it exits `0` only when both answer. `OAK_CENSUS_RPC_URL` does not add tracing. |
| `needs ETH for network fees: need at least <needed> wei including transaction value; held <held> wei. Send ETH to <address> on chain <chainId>. Approximately <needed in ETH> ETH needed; <held in ETH> ETH held.` | Wallet ETH cannot cover `value + gas * maxFeePerGas` (with 25% gas headroom). | Send native ETH on the named chain to `oak address` and retry. |
| `No active subscription. Read account for the plan and price; only the no-hold plan at 12.333333 USDG per 30 days is open. After the person approves, call oak_subscribe {"plan":"nohold"}. Reads still work.` | Action tool called without a subscription during the `curve` phase (`phase != 2`). | Read `account`, then with the person's approval call `oak_subscribe {"plan":"nohold"}` or run `oak subscribe --plan nohold`. |
| `No active subscription. Read account for the plan and price. The pool is warming up; both plans wait for 30 minutes of history before subscribing. Reads still work.` | Action tool called during the 30-minute post-graduation `warmup` window. | Wait until the pool has 30 minutes of history, then subscribe with `oak_subscribe` or `oak subscribe`. |
| `No active subscription. Read account for the plan and price, and top up USDG for the subscription. After the person approves, call oak_subscribe with plan "holder" or "nohold". Reads still work.` | Action tool called without a subscription during `ready`. | Top up USDG (and `$OAK` if joining holder), then with the person's approval call `oak_subscribe` or run `oak subscribe --plan holder` or `oak subscribe --plan nohold`. |
| `subscription ended <date>; read account for the plan and price. After the person approves, call oak_renew. Reads still work.` | `paidUntil` has passed. Reads remain open; actions are paused. | Top up USDG (and ETH for gas) if needed, then with the person's approval call `oak_renew`, run `oak renew` or start `oak mcp`. |
| `hold at least <N> $OAK (you hold <M>). Hold enough $OAK to restore access, or read account for the no-hold plan and price; after the person approves, cancel the current plan and call oak_subscribe {"plan":"nohold"}. Cancelling ends access immediately and forfeits remaining paid days. Reads still work.` / `Buy back <count> OAK (<count> OAK base units, token <oak>, decimals 18) to restore access.` | Holder-plan wallet's `$OAK` balance dipped below its tracked `signupOakCount`. | Buy back `$OAK` to at least `signupOakCount`; access resumes immediately with no new fee. |
| `Renewal/payment needs <amount> USDG (<amount> USDG base units, token <usdg>, decimals 6). Top up and run oak renew; tools are paused until payment succeeds.` | Wallet USDG balance is below the subscription or renewal price. | Send USDG (`0x5fc5360d0400a0fd4f2af552add042d716f1d168`, 6 decimals) and run `oak renew`. |
| ``your paid days carry over with `oak renew` when it is due`` | Grandfathered holder on a retired contract ran `oak subscribe` instead of `oak renew`. | Wait until `<= 3 days` remain and run `oak renew` to migrate with zero burn and carried paid time. |
| `Wallet journal is unresolved; wait for the pending transaction before a new action.` | An in-flight transaction in `~/.oak/<address>.pending.json` has not yet been reconciled. | Run `oak renew` or start `oak mcp` to reconcile or fee-bump the pending transaction. |
| `Already subscribed; use oak renew, or oak cancel before switching plans.` | `oak subscribe` called while a plan is already active. | Use `oak renew`, or run `oak cancel` (forfeiting remaining paid days) before switching plans. |

## Confirmation and current access

Hosted actions require a verified ERC-8004 identity and an active subscription in 0.2.0 paid mode. Since **0.1.1**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
