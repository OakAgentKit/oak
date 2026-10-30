# MCP Client Setup Guides

Oak Agent Kit (`@oakagentkit/addon`, available at launch) runs as a local `stdio` Model Context Protocol (MCP) server via `oak mcp`. One install connects your AI agent to a local self-custodial wallet and **100 MCP tools** across **25 ecosystem projects** on **Robinhood Chain** (`4663`).

---

## Shared Prerequisites (Do This Once)

### 1. Install the CLI (available at launch)

Requires **Node.js 22 LTS** (`>=22.12.0 <23`):

```bash
npm install -g @oakagentkit/addon
```

### 2. Create Your Wallet in Your Own Terminal

Run `oak init` **directly in your own system terminal, never through the AI agent**:

```bash
oak init
```

- Displays a 24-word recovery phrase once and prompts you to confirm three random words. Write the recovery phrase down offline; **Oak cannot recover a lost key**.
- Encrypts your private key with `AES-256-GCM` in `~/.oak/wallet.enc` (`0600`) and stores the encryption key in your OS keychain (or derives it from a `>= 12`-character terminal passphrase via `scrypt`).
- Your private key never leaves your computer, and the hosted Oak service never sees your key and never signs or sends a transaction.

### 3. Configure Your Network and RPC

Oak defaults to **Robinhood Chain mainnet** (`OAK_NETWORK=mainnet`, chain ID `4663`, `0x1237`). To test Oak's contracts and ERC-8004 identity on **Robinhood Chain Testnet** (`46630`, `0xb626`), opt in explicitly with `OAK_NETWORK=testnet` and `OAK_CHAIN_ID=46630`. If environment variables disagree with `~/.oak/config.json`, Oak refuses to start.

```bash
oak config set OAK_NETWORK mainnet
oak config set OAK_CHAIN_ID 4663
oak config set OAK_RPC_URL <your-robinhood-chain-4663-rpc-url>
oak config set OAK_USDG_ADDRESS 0x5fc5360d0400a0fd4f2af552add042d716f1d168
oak config set OAK_ETH_USDG_POOL_ADDRESS 0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca
# Contract addresses for OAK_SUBSCRIPTION_ADDRESS, OAK_TOKEN_ADDRESS, and OAK_ORACLE_ADDRESS are published at launch
```

### 4. Set Up Your ERC-8004 Identity and Subscribe

Read tools (`find_token`, `balances`, `price`, `quote`, `preview`, `history`, `positions`, `account`, and module reads) work immediately without an identity or subscription. Action tools require a verified ERC-8004 identity on `IdentityRegistry` (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`) and an active subscription:

```bash
# Link an existing ERC-8004 agent ID (gasless; owner signs an EIP-712 challenge in your terminal)
oak setup link <agentId>

# Or mint a new ERC-8004 agent ID on-chain (needs ETH for gas)
oak config set profile '{"type":"https://eips.ethereum.org/EIPS/eip-8004#registration-v1","name":"my-agent","description":"My Oak agent","image":"https://example.com/my-agent.png","services":[],"x402Support":false,"active":true,"registrations":[]}'
oak setup register

# Fund your wallet (ETH for gas, USDG for subscription/trading, and $OAK if joining the holder plan)
oak address
oak subscribe --plan nohold   # launch curve: holder is closed
```

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
3. Automatically renews an active subscription when `<= 3 days` remain before `paidUntil`, using local wallet signing and available USDG (unless cancelled with `oak cancel`).

Run `oak init --recover` in your own terminal to restore your 24-word backup on a new computer. To replace an existing wallet, use `oak init --recover --replace`; Oak preserves an encrypted backup and asks you to confirm the recovered address. Never enter recovery words in an agent chat, arguments, environment variables or MCP tools.

For stdio MCP, Oak needs an accessible persistent OS keychain (Linux: Secret Service in the same unlocked user/D-Bus session as the MCP client). A passphrase-only wallet currently supports interactive CLI commands in your own terminal; it cannot start `oak mcp` through a pipe. Do not send the passphrase through MCP or store it in argv/environment variables. To enable MCP for an existing fallback wallet, first configure a persistent keychain, then restore with `oak init --recover --replace` yourself in your terminal and confirm the address. Keep the old encrypted backup and recovery words offline.

Mainnet uses `https://api.oakagentkit.org` by default. Override it with `oak config set OAK_SERVER_URL <https-url>` or `OAK_SERVER_URL`; testnet requires an explicit matching service URL. Configure the published deployment addresses and your RPC before starting MCP.
