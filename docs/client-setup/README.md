# MCP client setup guides

Oak Agent Kit (`@oakagentkit/addon` 0.3.5, published on npm) runs as a local `stdio` Model Context Protocol (MCP) server via `oak mcp`. One install connects your AI agent to a local self-custodial wallet and an everyday MCP tool list across 35 ecosystem projects, plus `find_tool` and `run_tool` for the full catalog on **Robinhood Chain** (`4663`).

---

## Shared Prerequisites (Do This Once)

### 1. Install the CLI

Requires **Node.js 22.12.0 or newer** (`>=22.12.0`):

```bash
npm install -g @oakagentkit/addon
oak --version
oak address
oak status
```

On first use Oak creates a local wallet. Check the address and network, `keyProtection`, and any file-storage warning before funding it. `oak status` also reports your identity status and optional daily spending limit. While the hosted service is in private test mode, `actionAccess:false` is expected for an unlisted wallet; token reads remain available. Never send keys or recovery words to the agent.

### 2. Connect the MCP; the Wallet Creates Itself

Oak creates a wallet automatically when `oak mcp`, `oak address`, or another wallet command first runs. There are no recovery-word challenges or passphrase prompts. On first run, the agent calls `account`, relays the public address and selected network, asks once whether you want a daily spending limit in USD (skipped means no limit), asks you to fund the wallet with a little ETH for gas, and calls `balances` again after you fund it.

The private key stays local in `~/.oak/wallet.enc` (AES-256-GCM, `0600`, inside `~/.oak` at `0700`). A random encryption key is stored in macOS Keychain, Linux persistent Secret Service, or Windows Credential Manager when available. Otherwise Oak saves a random file key in the same owner-only directory (`wallet-key-<id>`, `0600`). This fallback relies on your OS account and filesystem permissions: someone who can read both files can unlock the wallet. No passphrase is requested. Keep only the funds your agent needs.

Later runs reuse the wallet. A corrupt wallet or unavailable existing keychain never creates a replacement. Existing keychain and passphrase wallets keep their format; legacy passphrase wallets still need terminal unlock and cannot run piped MCP.

Backups are optional. When you hold more than pocket change, run `oak export` **in your own terminal, never through the agent** and keep the exported key offline. `oak backup` prints guidance without unlocking or exporting anything. Automatic wallets have no recovery phrase. `oak init --recover` accepts an exported private key or a legacy 24-word phrase, hidden in your terminal; `--replace` preserves the previous encrypted wallet. Oak cannot recover a lost key.

### 3. Fund and Approve Setup

After funding, ask the agent to register a public ERC-8004 identity with `oak_setup {"mode":"register"}`. Oak supplies a default registration-v1 profile; you can provide your own `profile`. Registration costs ETH and publishes the profile. Linking an existing ID uses `oak_setup {"mode":"link","agentId":"<id>"}`; if this wallet owns it, signing is automatic. An external NFT owner must sign in their own terminal because the agent does not control that owner's wallet.

Oak is free to use. All transactions retain previews, local checks, and yes-or-no confirmation in chat (preparing with a listed action tool or `oak_prepare`, then calling `oak_execute` with `{"actionId": "<actionId>"}` after you say yes). You can set or change an optional daily spending limit in USD anytime in chat (`oak_spending_limit`).

The remaining user steps are funding ETH for network fees, saying yes in chat to public identity registration or transactions, and signing for an external identity owner when applicable. Read tools remain available without an identity.

### 4. Service Defaults

Mainnet uses `https://api.oakagentkit.org` and the public Robinhood Chain RPC by default. The service's public `GET /v1/config` supplies deployed Oak token, oracle, burner, and pool addresses; RPC credentials and server secrets are never returned. No contract-address copying is required with an upgraded deployed service. Explicit local deployment pins must agree, and mainnet/testnet settings cannot be mixed. Transaction signing requires `eth_simulateV1` with complete per-call logs and `traceTransfers`; the default public RPC supplies that evidence. `debug_traceCall`/`callTracer` is optional extra coverage: when supported Oak validates nested delegate targets, while an explicit unsupported-method response selects simulation-only mode and leaves that documented residual risk. A keyed RPC is therefore an optional reliability and extra-coverage override, not a prerequisite for the default simulation-only path. Malformed responses, transport errors, or loss of a tracer previously shown available fail closed.

Oak is free to use on mainnet; version 0.3.5 is available on npm.
$OAK has graduated on Pons. Reads need no identity; actions require
a verified ERC-8004 identity (except the free `gloam_claim` action). Call `account` to check your
wallet address, network, and ERC-8004 identity status. See [access and pricing](../access-and-pricing.md).
Testnet still requires explicitly matching service, RPC and deployment settings.
The commands below are advanced operator overrides, not the normal first-run path.

### Copy-paste Setup Prompt

> Set up Oak for this AI agent. Install @oakagentkit/addon (Node.js 22.12.0 or newer) and connect the local MCP command `oak mcp`. Call account, tell me the public wallet address and network, ask once whether I want a daily spending limit in USD (`oak_spending_limit`), and ask me to send a little ETH for gas. Re-check balances after I fund it. Do not run oak init or oak export, read wallet/key files, or ask for keys or recovery words. Explain identity registration and its ETH gas cost, then get my yes in chat before registering. Tell me optional backup guidance with oak backup.

---

## Choose Your MCP Client

| Client | Configuration Path / Command | Guide |
| :--- | :--- | :--- |
| **Claude Desktop** | `claude_desktop_config.json` | [`claude-desktop.md`](claude-desktop.md) |
| **Claude Code** | `claude mcp add oak -- oak mcp` | [`claude-code.md`](claude-code.md) |
| **Cursor** | `.cursor/mcp.json` or `~/.cursor/mcp.json` | [`cursor.md`](cursor.md) |
| **Codex** | `~/.codex/config.toml` | [`codex.md`](codex.md) |
| **Gemini** | `~/.gemini/settings.json` | [`gemini.md`](gemini.md) |
| **Generic MCP (Grok & stdio hosts)** | `command: oak`, `args: ["mcp"]` | [`generic-mcp.md`](generic-mcp.md) |

---

## What `oak mcp` Does While Running

On startup and once every hour, `oak mcp`:

1. Reconciles any pending local transaction journal entry (`~/.oak/<address>.pending.json`).
2. Verifies your ERC-8004 identity status (if the NFT is transferred or burned, or you run `oak identity unlink`, action tools pause and local `identity` is cleared while reads stay open; during a temporary RPC or service outage, local `identity` is preserved while reads stay open).

Run `oak init --recover` in your own terminal to restore an exported private key or a legacy 24-word backup on a new computer. To replace an existing wallet, use `oak init --recover --replace`; Oak preserves an encrypted backup and asks you to confirm the recovered address. Never enter recovery words in an agent chat, arguments, environment variables or MCP tools.

New automatic wallets work without a keychain using owner-only file storage. Existing passphrase wallets still require terminal unlock; see [headless guidance](../headless-wallet.md).

Mainnet uses `https://api.oakagentkit.org` by default. Override it with `oak config set OAK_SERVER_URL <https-url>` or `OAK_SERVER_URL`; testnet requires an explicit matching service URL. The service supplies public deployment pins when needed; explicit overrides remain available.

## Confirmation support

Every action uses two-step chat confirmation (`oak_prepare` or a listed common action tool, followed by `oak_execute` with `actionId`).
First, the agent calls a listed common action tool (`swap`, `send`, `lend`, `withdraw`, `borrow`, `repay`, `bridge`) or `oak_prepare` with `{"name": "<tool>", "arguments": {...}}`, which builds and simulates the transaction without signing and gives a six-part summary (what leaves the wallet, what comes back, the destination contract, the exact approval, the estimated network fee, and the USD value) plus a single-use `actionId` and UTC expiry.
The agent shows that summary in chat and asks for a yes or no.
When you say yes, the agent calls `oak_execute` with `{"actionId": "<the exact actionId>"}`, which re-simulates immediately before signing, checks that terms have not worsened and checks your optional daily spending limit in USD (`oak_spending_limit`), and signs locally.
Reads and session authentication do not prompt. See [security](../security.md).

### Per-client MCP tool annotations and approval prompts

Oak sets [MCP `2025-03-26` `ToolAnnotations`](https://modelcontextprotocol.io/specification/2025-03-26/server/tools) on the two-step approval tools:

- `oak_prepare`: `{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}` — previews and simulates without signing, so clients that honour `readOnlyHint` do not add an extra pre-tool dialog on the dry-run summary.
- `oak_execute`: `{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false, "openWorldHint": true}` — flags signing and broadcasting as a state-changing action so clients that inspect `destructiveHint` prompt before calling `oak_execute`.

Oak sets `ToolAnnotations` only and adds no in-band MCP elicitation form; two-step chat confirmation (`oak_prepare` summary in chat, then your yes before `oak_execute`) remains required, and client bypass or auto-approve settings still skip the client's own pre-tool prompt:

| Client | Default prompt behaviour | Honours `readOnlyHint` / `destructiveHint` | Bypass / auto-approve flags that skip client pre-tool prompts | Verified reference |
| :--- | :--- | :--- | :--- | :--- |
| **Claude Code** | Prompts per tool by default (`Allow once`, `Always allow`, `Deny`) and relaxes prompts on `readOnlyHint: true`. | Yes | `--dangerously-skip-permissions` (`bypassPermissions`) or session/workspace `Always allow` rules. | [Claude Code settings](https://code.claude.com/docs/en/settings), [claude-code#7108](https://github.com/anthropics/claude-code/issues/7108), [claude-code#16295](https://github.com/anthropics/claude-code/issues/16295) |
| **Claude Desktop** | Prompts on first tool call (`Allow once`, `Always allow`, `Deny`) and separates read-only tools from write/modify tools. | Yes | Clicking `Always allow` for a tool in the workspace modal skips future pre-tool prompts in that chat/workspace. | [MCP tools spec](https://modelcontextprotocol.io/specification/2025-03-26/server/tools), [claude-ai-mcp#153](https://github.com/anthropics/claude-ai-mcp/issues/153) |
| **Cursor** | `Ask Every Time` prompts per tool; `Auto-review` runs Cursor's permission layer and classifier subagent. | Yes | `Run Everything` mode or adding the server/tool to `.cursor/permissions.json`. | [Cursor MCP docs](https://docs.cursor.com/context/model-context-protocol), [Cursor changelog](https://cursor.com/changelog) |
| **OpenAI Codex CLI** | Prompts by default (`--ask-for-approval on-request`) unless a tool is marked `readOnlyHint: true` and closed-world. | Yes | `--dangerously-bypass-approvals-and-sandbox` (`--yolo`), `--ask-for-approval never`, or `--approve-for-me`. | [codex#6992](https://github.com/openai/codex/issues/6992) |
| **Gemini CLI** | Prompts per tool by default unless the server is trusted or matched by a policy rule. | Yes | `--yolo` (`--approval-mode=yolo`) or setting `"trust": true` on the server in `~/.gemini/settings.json`. | [Gemini CLI MCP docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md), [gemini-cli#19654](https://github.com/google-gemini/gemini-cli/issues/19654) |
| **VS Code (Copilot)** | Auto-runs `readOnlyHint: true` tools (since v1.100) and prompts before mutating or `destructiveHint: true` tools. | Yes | Selecting `Always Allow` for the tool, session, or workspace in the approval dropdown. | [VS Code v1.100](https://code.visualstudio.com/updates/v1_100), [VS Code MCP guide](https://code.visualstudio.com/api/extension-guides/ai/mcp) |
| **Grok / xAI Remote MCP** | No native pre-tool prompt in the xAI Remote MCP API (`allowed_tools` is a static allowlist). | No | Any tool in `allowed_tools` runs without a client prompt; keep `oak_execute` behind human chat confirmation. | [xAI Remote MCP docs](https://docs.x.ai/docs/tools/remote-mcp) |

## Quick connections

Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. These shortcuts run
`npx -y @oakagentkit/addon@0.3.5 mcp`, so no global Oak install is needed.
Review your app’s install confirmation, then start a fresh session. If you already
configured Oak manually, use that connection or remove it before adding a second one.
Installing connects tools; identity registration and transactions still need
your yes in chat.

In Claude Code, run these two commands:

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

Restart Claude Code, then check `/mcp` for `plugin:oak:oak`. On Claude Code
2.1.292 or later, the shell shortcut is `claude plugin install oak --marketplace OakAgentKit/oak`.

[Add to Cursor](https://cursor.com/install-mcp?name=oak&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBvYWthZ2VudGtpdC9hZGRvbkAwLjMuNSIsIm1jcCJdfQ%3D%3D) · [Install in VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522oak%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540oakagentkit%252Faddon%25400.3.5%2522%252C%2522mcp%2522%255D%257D)


Gloam is opt-in. Install its optional engine beside the add-on to use private USDG payments:

```sh
npx -y -p @oakagentkit/addon@0.3.5 -p @oakagentkit/gloam@0.3.5 oak mcp
```

The default MCP command keeps the add-on alone. Gloam tools remain discoverable without the engine and give this install command when called. Only shield deposits sign wallet transactions. Pay, claim and cash-out make proofs locally for Gloam's relay; every action requires human confirmation, including free claims. Never paste a note or key into an agent. Back up Gloam notes with `oak export` in your own terminal; backups cover only the notes present when made.
