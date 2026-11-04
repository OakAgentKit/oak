# MCP client setup guides

Oak Agent Kit (`@oakagentkit/addon`, published on npm) runs as a local `stdio` Model Context Protocol (MCP) server via `oak mcp`. One install connects your AI agent to a local self-custodial wallet and an everyday MCP tool list across 28 ecosystem projects, plus `find_tool` and `run_tool` for the full catalog on **Robinhood Chain** (`4663`).

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

On first use Oak creates a local wallet. Check the address and network, `keyProtection`, and any file-storage warning before funding it. `oak status` also reports confirmation mode and the automatic approval budget. While the hosted service is in private test mode, `actionAccess:false` is expected for an unlisted wallet; token reads remain available. Never send keys or recovery words to the agent.

### 2. Connect the MCP; the Wallet Creates Itself

Oak creates a wallet automatically when `oak mcp`, `oak address`, or another wallet command first runs. There are no recovery-word challenges or passphrase prompts. The agent calls `account`, relays the public address and selected network, asks you to fund it with a little ETH for gas and USDG, then calls `balances` again after you fund it.

The private key stays local in `~/.oak/wallet.enc` (AES-256-GCM, `0600`, inside `~/.oak` at `0700`). A random encryption key is stored in macOS Keychain, Linux persistent Secret Service, or Windows Credential Manager when available. Otherwise Oak saves a random file key in the same owner-only directory (`wallet-key-<id>`, `0600`). This fallback relies on your OS account and filesystem permissions: someone who can read both files can unlock the wallet. No passphrase is requested. Keep only the funds your agent needs.

Later runs reuse the wallet. A corrupt wallet or unavailable existing keychain never creates a replacement. Existing keychain and passphrase wallets keep their format; legacy passphrase wallets still need terminal unlock and cannot run piped MCP.

Backups are optional. When you hold more than pocket change, run `oak export` **in your own terminal, never through the agent** and keep the exported key offline. `oak backup` prints guidance without unlocking or exporting anything. Automatic wallets have no recovery phrase. `oak init --recover` accepts an exported private key or a legacy 24-word phrase, hidden in your terminal; `--replace` preserves the previous encrypted wallet. Oak cannot recover a lost key.

### 3. Fund and Approve Setup

After funding, ask the agent to register a public ERC-8004 identity with `oak_setup {"mode":"register"}`. Oak supplies a default registration-v1 profile; you can provide your own `profile`. Registration costs ETH and publishes the profile. It does not require a subscription. Linking an existing ID uses `oak_setup {"mode":"link","agentId":"<id>"}`; if this wallet owns it, signing is automatic. An external NFT owner must sign in their own terminal because the agent does not control that owner's wallet.

The agent reads `account` for phase and price, explains the recurring payment, and gets your plan approval before calling `oak_subscribe {"plan":"nohold"}` (or `holder`). Launch curve: no-hold only, 12.333333 USDG per 30 days. Warmup: both plans wait for 30 minutes of history. Ready: both plans follow the quoted terms; holder requires OAK and a one-time sign-up burn. `oak_renew {}` reconciles or renews. All transactions retain previews and local signing. Merely funding a wallet does not authorize a paid subscription.

The remaining user steps are funding, authorizing public registration and the recurring plan, and signing for an external identity owner when applicable. These steps move funds, publish data, or require an independently controlled wallet. Read tools remain available without identity or subscription.

### 4. Service Defaults

Mainnet uses `https://api.oakagentkit.org` and the public Robinhood Chain RPC by default. The service's public `GET /v1/config` supplies deployed Oak subscription, token, oracle and pool addresses when a subscription operation needs them; RPC credentials and server secrets are never returned. No contract-address copying is required with an upgraded deployed service. Explicit local deployment pins must agree, and mainnet/testnet settings cannot be mixed. Transaction signing requires `eth_simulateV1` with complete per-call logs and `traceTransfers`; the default public RPC supplies that evidence. `debug_traceCall`/`callTracer` is optional extra coverage: when supported Oak validates nested delegate targets, while an explicit unsupported-method response selects simulation-only mode and leaves that documented residual risk. A keyed RPC is therefore an optional reliability and extra-coverage override, not a prerequisite for the default simulation-only path. Malformed responses, transport errors, or loss of a tracer previously shown available fail closed.

Mainnet paid access is live on the 0.2.0 deployment; the Oak 0.2.4 install pins are prepared, with publication pending.
$OAK has graduated on Pons. Reads need neither identity nor subscription; actions require
a verified ERC-8004 identity and an active subscription. Call `account` for phase,
available plans and price; both plans wait during warmup. See [access and pricing](../access-and-pricing.md).
Testnet still requires explicitly matching service, RPC and deployment settings.
The commands below are advanced operator overrides, not the normal first-run path.

### Copy-paste Setup Prompt

> Set up Oak for this AI agent. Install @oakagentkit/addon (Node.js 22.12.0 or newer) and connect the local MCP command `oak mcp`. Call account, tell me the public wallet address and network, and ask me to send a little ETH for gas and USDG. Re-check balances after I fund it. Do not run oak init or oak export, read wallet/key files, or ask for keys or recovery words. Explain identity registration and subscription costs, then get my approval before registering and subscribing. Tell me optional backup guidance with oak backup.

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
3. Attempts renewal when `<= 3 days` remain before `paidUntil`, using local wallet signing and available USDG. In default ask mode, new payment signatures require human confirmation; unattended renewal requires the owner's explicit auto setting. `oak cancel` ends access immediately and forfeits paid days.

Run `oak init --recover` in your own terminal to restore an exported private key or a legacy 24-word backup on a new computer. To replace an existing wallet, use `oak init --recover --replace`; Oak preserves an encrypted backup and asks you to confirm the recovered address. Never enter recovery words in an agent chat, arguments, environment variables or MCP tools.

New automatic wallets work without a keychain using owner-only file storage. Existing passphrase wallets still require terminal unlock; see [headless guidance](../headless-wallet.md).

Mainnet uses `https://api.oakagentkit.org` by default. Override it with `oak config set OAK_SERVER_URL <https-url>` or `OAK_SERVER_URL`; testnet requires an explicit matching service URL. The service supplies public deployment pins when needed; explicit overrides remain available.

## Confirmation support

Use a client that supports **MCP form elicitation** — the protocol's confirmation form.
Ask mode is the default. Decline, timeout or a missing form stops action signing;
reads and session authentication do not prompt. Check support in your installed
client version rather than assuming every host below can confirm actions.
The generic `oak call` CLI has no MCP confirmation form and cannot sign in ask mode.

The owner may select `oak config set confirm auto` in their own terminal for
unattended operation, and restore prompts with `oak config set confirm ask`.
Only selecting auto requires a TTY; no MCP tool exposes this setting. Never ask an
agent to allocate a PTY to change it. Auto retains local transaction checks.
Do not enable it merely to make a connection test pass. See [security](../security.md).

Verify your installed version with `oak --version`; 0.1.0 does not include the
confirmation or hardened local checks described here, which arrived in 0.1.1.

## Quick connections

Requires Node.js 22.12.0 or newer (`>=22.12.0`) and npm on your PATH. These shortcuts run
`npx -y @oakagentkit/addon@0.2.4 mcp`, so no global Oak install is needed.
Review your app’s install confirmation, then start a fresh session. If you already
configured Oak manually, use that connection or remove it before adding a second one.
Installing connects tools; identity registration and paid subscriptions still need
separate approval.

In Claude Code, run these two commands:

```text
/plugin marketplace add OakAgentKit/oak
/plugin install oak@oak-agent-kit
```

Restart Claude Code, then check `/mcp` for `plugin:oak:oak`. On Claude Code
2.1.292 or later, the shell shortcut is `claude plugin install oak --marketplace OakAgentKit/oak`.

[Add to Cursor](https://cursor.com/install-mcp?name=oak&config=eyJjb21tYW5kIjoibnB4IiwiYXJncyI6WyIteSIsIkBvYWthZ2VudGtpdC9hZGRvbkAwLjIuNCIsIm1jcCJdfQ%3D%3D) · [Install in VS Code](https://vscode.dev/redirect?url=vscode%3Amcp%2Finstall%3F%257B%2522name%2522%253A%2522oak%2522%252C%2522command%2522%253A%2522npx%2522%252C%2522args%2522%253A%255B%2522-y%2522%252C%2522%2540oakagentkit%252Faddon%25400.2.4%2522%252C%2522mcp%2522%255D%257D)
