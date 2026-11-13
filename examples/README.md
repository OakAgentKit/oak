# Oak examples (MIT)

Three small Node.js 22 examples using only exported npm package APIs:

- [01-quickstart-mcp](01-quickstart-mcp/): connect an MCP client to the add-on and list names and schemas.
- [02-preview-sign-swap](02-preview-sign-swap/): prepare a swap, read the plain summary, answer yes or no, then execute the exact action ID after yes.
- [03-portfolio-agent](03-portfolio-agent/): read balances and positions across projects.

## Install and test packed packages

Prerequisites: Node.js **22.12+ / 22.x**, npm, and the two release `.tgz` files.
The examples target core and add-on **0.3.7**. Use
matching release archives for checks; no private repository source is needed.
From this directory, one command installs both tarballs into a fresh local
sandbox and runs every offline test:

```sh
npm run test:packed -- /path/to/oakagentkit-core-0.3.7.tgz /path/to/oakagentkit-addon-0.3.7.tgz
```

These archives must be a matching reviewed release pair. The packed test installs
the archives explicitly with `--package-lock=false`; it does not rely on the
checked-in lockfile or workspace links. This is the supported 0.3.7 check here.

It prints the installed sandbox path. `cd` there and run `npm run quickstart`,
`npm run preview`, or `npm run portfolio`. Each defaults to labelled fixture
mode: no funded wallet, RPC, hosted service, authentication signing, or LLM.
Install requires registry access for third-party dependencies (the MCP SDK is
pinned to 1.32.2). After `.cache` is populated, prefix the command with
`npm_config_offline=true` for a completely offline reinstall and test.
No dependency lifecycle scripts execute. The sandbox and cache stay ignored.

For a direct install instead, run `npm install --ignore-scripts /path/to/CORE.tgz
/path/to/ADDON.tgz` here, followed by `npm test`. Those archives
can also be replaced with matching published versions of `@oakagentkit/core` and
`@oakagentkit/addon`.

## Optional live reads (run yourself)

Use a configured **mainnet** Oak wallet created automatically by `oak address`
or the first MCP startup, never through an agent. Set `OAK_EXAMPLE_LIVE=1` and
`OAK_SERVER_URL` to the published service URL, then run an example. Never put
wallet secrets in environment variables. `.env.example` files list names only;
these scripts do not automatically read `.env` files. Export the variables in
your terminal. The service receives your wallet address and read arguments.

The shared client connects the MCP SDK to the exported `createBridge` through
`InMemoryTransport`. By default it supplies a disabled sender and loads no recipes.
Live reads load the local signer solely for Oak session/request authentication messages;
transaction and typed-data signing are disabled. These examples do not register
identities, sign transactions, or send them, even after yes. The swap's offline
fixture injects a mock sender to demonstrate prepare and execute calls without
signing or broadcasting. Optional live mode supports reads; the disabled live
sender refuses swap preparation. No identity is needed for the read tools.

The examples are mainnet-only (`4663`); testnet has no swap routes or portfolio
coverage across projects. Results depend on configured project readers;
module error rows and incomplete or unindexed coverage remain visible.

## Approval flow in 0.3.7

1. Call `oak_prepare {name: "swap", arguments: {quoteId}}` (or the listed `swap`
   action tool). This builds and simulates without signing.
2. Show the returned plain summary: what the action does, what leaves the wallet,
   what comes back or minimum received, fees, token approval and warnings. Show
   the exact `actionId` and UTC expiry too, then ask the person for yes or no.
3. After the person's yes, call `oak_execute {actionId}` once with that exact ID.
   No, unclear answers, EOF and noninteractive runs stop before execute.

The swap example checks expiry again after the answer. Expired actions or failed
execution need a fresh prepare step and another yes; nothing retries silently.
In production Oak re-simulates, checks unchanged terms, local signing guards and
the optional daily spending limit before signing. The fixture models the call
boundary and gives back `not_submitted`; it does not implement those sender checks.
The directory name and `npm run preview` command remain for existing links.

## Verification boundary

Tests use the real packed add-on bridge, real MCP client/transport, and real
core quote/calldata/amount helpers. The HTTP service responses and session
headers and sender are fixtures. Paid diagnostics are off and token-snapshot
transport is stubbed. Signing and broadcast traps fail if invoked. Tests prove
client wiring, exact finite approvals, summary/yes/execute ordering, action
rejection and partial-error handling. They do not prove live
RPC availability, execution, auth/keychain access, prices or external settlement.
A successful buy simulation does not establish sellability; simulation excludes
gas. See [eval-design.md](eval-design.md) for failure controls.

Oak keeps `tools/list` short. These examples omit setup flows. Tools outside that
list remain reachable: call `find_tool` with an exact name for its input schema,
then `run_read_tool` for reads or `run_tool` for actions. Actions still prepare
first and require the person's yes before `oak_execute`. Compare your installed catalog.

Version 0.1.2 historically listed 102 CLI tools and 100 through the read-only examples; testnet CLI discovery listed 16. These historical counts do not establish the newer testnet surface.

## Direct installation from npm

The manifest targets **0.3.7**, but the checked-in lockfile still targets **0.2.7**.
Release packaging must update and review that lockfile and the final Oak package
integrity values before using `npm ci` for 0.3.7. After that update, run:

```sh
npm ci --ignore-scripts --no-audit --no-fund
npm test
```

To verify matching local release archives, use
`test-packed.mjs` instead.
These examples deliberately disable signing; the fixture's yes exercises only a
mock execution request. Hosted read calls such as `find_token` are available
without an identity. Oak is free to use; hosted actions require a verified
ERC-8004 identity (except the free `gloam_claim` action).
