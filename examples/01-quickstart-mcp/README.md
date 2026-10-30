# 01 — Connect an MCP client

Goal: list the add-on's tools and JSON input schemas through a real MCP session.

Prerequisites: Node 22 and the packed-package installation described in the
[parent README](../README.md). No wallet or service is needed for discovery.

From the installed examples directory:

```sh
npm run quickstart
node --test 01-quickstart-mcp/example.test.mjs
```

Expected output: fixture-mode label, `100 tools (names and JSON input schemas)`
and a JSON array including `quote`, `preview`, `balances`, `positions`,
`pons_launch_options`, `pons_transfer_creator_fee_recipient`, and `pons_set_buyback`.
No tool is executed. `shared/client.mjs` connects the MCP client to the exported
add-on bridge using the SDK's in-memory transport and closes both endpoints.
