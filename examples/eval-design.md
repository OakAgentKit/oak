# Offline evaluation

Question: can a builder install the release archives and exercise all three
examples through the public APIs without a funded wallet, live RPC or sending?
Oracle: all Node tests pass in an isolated tarball install; deliberate action,
expiry, token mismatch and simulation failure controls are rejected.
Technique: concrete harness plus source review of the package exports.

- Discovery: actual MCP handshake and 100 schemas, including Pons creator tools;
  assert zero HTTP calls during discovery.
- Swap: quote and unsigned build through core; inspect the encoded exact approval;
  preview appears before confirmation; false/string/noninteractive confirmations
  cannot advance; even true yields a manual handoff and zero swap calls.
- Failure controls: missing calldata, expired quote, wrong token pair, unverified
  lookup, failed simulation, numeric amount, expiry during confirmation.
- Portfolio: exactly two read calls, lossless base units/human formatting,
  multiple project positions and explicit partial-outage warning.
- Custody controls: deliberate action-tool invocation returns an MCP error; disabled
  sender throws; tool-level errors are propagated rather than parsed as success.

No LLM/provider is integrated: prompt-cache hit rate and model cost per request
are not applicable. Tests have zero model requests. Fixtures replace network
and session signing; live service, wallet/keychain and settlement are unmeasured.
