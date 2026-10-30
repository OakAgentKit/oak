# Oak examples (MIT)

Three small Node.js 22 examples using only exported npm package APIs:

- [01-quickstart-mcp](01-quickstart-mcp/): connect an MCP client to the add-on and list names and schemas.
- [02-preview-sign-swap](02-preview-sign-swap/): quote, build unsigned calldata, simulate, and pause for review.
- [03-portfolio-agent](03-portfolio-agent/): read balances and positions across projects.

## Install and test packed packages

Prerequisites: Node.js **22.12+ / 22.x**, npm, and the two release `.tgz` files.
The Oak packages are not yet published. Obtain the core and add-on archives
from the release pack output; no private repository source is needed.
From this directory, one command installs both tarballs into a fresh local
sandbox and runs every offline test:

```sh
node test-packed.mjs /path/to/oakagentkit-core-0.0.0.tgz /path/to/oakagentkit-addon-0.0.0.tgz
```

It prints the installed sandbox path. `cd` there and run `npm run quickstart`,
`npm run preview`, or `npm run portfolio`. Each defaults to labelled fixture
mode: no funded wallet, RPC, hosted service, authentication signing, or LLM.
Install requires registry access for third-party dependencies (the MCP SDK is
pinned to 1.32.2). After `.cache` is populated, prefix the command with
`npm_config_offline=true` for a completely offline reinstall and test.
No dependency lifecycle scripts execute. The sandbox and cache stay ignored.

For a direct install instead, run `npm install --ignore-scripts /path/to/CORE.tgz
/path/to/ADDON.tgz` here, followed by `npm test`. Once published, those archives
can be replaced with matching released versions of `@oakagentkit/core` and
`@oakagentkit/addon`.

## Optional live reads (run yourself)

Use a configured **mainnet** Oak wallet created automatically by `oak address`
or the first MCP startup, never through an agent. Set `OAK_EXAMPLE_LIVE=1` and
`OAK_SERVER_URL` to the published service URL, then run an example. Never put
wallet secrets in environment variables. `.env.example` files list names only;
these scripts do not automatically read `.env` files. Export the variables in
your terminal. The service receives your wallet address and read arguments.

The shared client connects the MCP SDK to the exported `createBridge` through
`InMemoryTransport`. It deliberately supplies a disabled sender and renewal
callback, and loads no recipes. It does **not** launch the normal `oak mcp`
CLI, whose startup/hourly subscription renewal can send payments. Live reads
load the local signer solely for Oak session/request authentication messages;
transaction and typed-data signing are disabled. These examples do not register
identities, renew subscriptions, sign transactions, or send them, even after
confirmation. No identity or active subscription is needed for the read tools.

The examples are mainnet-only (`4663`); testnet has no swap routes or portfolio
coverage across the 25 modules. Results depend on configured project readers;
module error rows are surfaced, not reported as empty successful portfolios.

## Verification boundary

Tests use the real packed add-on bridge, real MCP client/transport, and real
core quote/calldata/amount helpers. The HTTP service responses and session
headers are fixtures. They prove client wiring, exact approvals, confirmation
ordering, action rejection, and partial-error handling. They do not prove live
RPC availability, execution, auth/keychain access, prices or external settlement.
A successful buy simulation does not establish sellability; simulation excludes
gas. See [eval-design.md](eval-design.md) for failure controls.

The bridge currently lists 100 mainnet tools when both identity callbacks are
present, including the three Pons creator tools. Discovery tests pin the actual
packed-package manifest; compare your installed version when checking tool counts.
