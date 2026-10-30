# Headless wallet support

Stdio MCP needs an accessible persistent OS keychain.
On Linux, install and unlock Secret Service in the same user and D-Bus session as the MCP client.
macOS uses Keychain; Windows uses Credential Manager.
Verify `oak address` in your own terminal before connecting your MCP client.
A passphrase-only wallet supports interactive CLI use in your terminal; it cannot start a piped `oak mcp` process.

Run `oak init`, recovery and `oak export` yourself in your own terminal, never through an agent or agent-allocated PTY.
Never put a passphrase, private key or recovery words in tool arguments, environment variables or chat.
To migrate a passphrase wallet, configure a persistent keychain, then run `oak init --recover --replace` yourself.
Confirm the recovered address, keep the encrypted backup, and store your recovery words offline.
Recovery restores the same wallet and sends no transaction. Oak cannot recover a lost key.

Starting `oak mcp` can renew subscriptions with local signing and available USDG when renewal is due.
Use the [client setup prerequisites](client-setup/README.md) before connecting a host.
