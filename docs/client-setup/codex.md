# Codex Setup

Install Oak and connect the MCP below. The wallet creates itself on first use; your agent calls `account`, asks you to fund the returned address with ETH and USDG on the named network, then re-checks `balances`. See [shared setup](README.md#shared-prerequisites-do-this-once) for identity registration, subscription approval and optional backup guidance.

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
- Renewal can run within 3 days of expiry while `oak mcp` is running. Since 0.1.1, new payment signatures require human confirmation by default; unattended renewal requires the owner's explicit auto setting.

## Confirmation and current access

Hosted actions are team-only until token and subscription launch. Since **0.1.1**,
action signing requires your client's MCP confirmation form by default. A missing
form, decline or timeout stops signing. Verify form support in your installed client;
a connection or tool list alone does not establish action support.
Read [shared confirmation guidance](README.md#confirmation-support) before testing an action.
