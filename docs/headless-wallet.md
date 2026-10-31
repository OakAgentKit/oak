# Headless wallet support

Oak creates a wallet automatically when `oak mcp`, `oak address`, or another wallet command first runs. There are no recovery-word challenges or passphrase prompts. The agent calls `account`, relays the public address and selected network, asks you to fund it with a little ETH for gas and USDG, then calls `balances` again after you fund it.

The private key stays local in `~/.oak/wallet.enc` (AES-256-GCM, `0600`, inside `~/.oak` at `0700`). A random encryption key is stored in macOS Keychain, Linux persistent Secret Service, or Windows Credential Manager when available. Otherwise Oak saves a random file key in the same owner-only directory (`wallet-key-<id>`, `0600`). This fallback relies on your OS account and filesystem permissions: someone who can read both files can unlock the wallet. No passphrase is requested. Keep only the funds your agent needs.

Later runs reuse the wallet. A corrupt wallet or unavailable existing keychain never creates a replacement. Existing keychain and passphrase wallets keep their format; legacy passphrase wallets still need terminal unlock and cannot run piped MCP.

Backups are optional. When you hold more than pocket change, run `oak export` **in your own terminal, never through the agent** and keep the exported key offline. `oak backup` prints guidance without unlocking or exporting anything. Automatic wallets have no recovery phrase. `oak init --recover` accepts an exported private key or a legacy 24-word phrase, hidden in your terminal; `--replace` preserves the previous encrypted wallet. Oak cannot recover a lost key.

## Existing passphrase wallets and optional migration

An existing keychain wallet needs access to its original persistent OS keychain. New automatic wallets also support owner-only file storage.
On Linux, install and unlock Secret Service in the same user and D-Bus session as the MCP client.
macOS uses Keychain; Windows uses Credential Manager.
Verify `oak address` in your own terminal before connecting your MCP client.
A passphrase-only wallet supports interactive CLI use in your terminal; it cannot start a piped `oak mcp` process.

Run `oak init`, recovery and `oak export` yourself in your own terminal, never through an agent or agent-allocated PTY.
Never put a passphrase, private key or recovery words in tool arguments, environment variables or chat.
To migrate a passphrase wallet, configure a persistent keychain, then run `oak init --recover --replace` yourself.
Confirm the recovered address, keep the encrypted backup, and store your recovery words offline.
Recovery restores the same wallet and sends no transaction. Oak cannot recover a lost key.

Starting `oak mcp` can renew subscriptions with local signing and available USDG when renewal is due. Since **0.1.1**, new renewal signatures prompt in default ask mode.
Use the [client setup prerequisites](client-setup/README.md) before connecting a host.

## Unattended operation

Automatic wallet creation works without a terminal. Action signing in default
`confirm ask` mode still needs an MCP client that supports form elicitation.
A headless process without that form refuses new action signatures.
The owner can deliberately select `oak config set confirm auto` in their own
terminal to skip prompts; local transaction checks remain. Restore prompts with
`oak config set confirm ask`. Never have an agent allocate a PTY to choose auto.
See [security](security.md) for what is checked and what remains outside those checks.
