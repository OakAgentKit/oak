# Public CI

These workflows run at the public repository root: copy this .github directory
with the public docs/examples/contracts candidate. They never publish packages,
deploy contracts, request wallet keys, or use repository secrets. Fork PRs use
pull_request, never pull_request_target; checkout credentials are not persisted.
CodeQL alone requests security-events:write for SARIF upload; GitHub handles the
restricted fork token. All other jobs request contents:read only.

Examples check the exact versions in examples/package.json against npm. Only
404 responses skip install/tests, with a notice naming the missing versions.
Network errors, HTTP 5xx/auth failures and malformed JSON/metadata fail; none
are treated as an unpublished-version skip. Set the repository Actions
variable OAK_EXAMPLES_REQUIRE_PUBLISHED=true at launch to forbid that skip, and
update examples/package.json to real published versions (currently 0.0.0).
Local packed-package testing remains documented in examples/README.md.

Contracts require contracts/foundry.toml or packages/contracts/foundry.toml.
A missing contract tree fails explicitly. The candidate includes the contract
sources, tests, deployment scripts used by tests, remappings and a dependency
manifest. deployments/ is a placeholder, not a claim of live deployment.
Dependency and compiler provisioning uses network access. forge build and forge
test themselves use --offline with checksum-pinned solc 0.8.26. Fork/network
integration tests requiring RPC credentials are outside this offline check.

Link checks include local README/docs links and remote URLs; missing assets and
not-yet-live launch URLs are failures to repair in the content release. No broad
HTTP status or path exclusions hide those failures. Only x.com/twitter.com
links are excluded because these hosts return HTTP 403 to automated checks.

Gitleaks uses the private export's reviewed config copied here; keep its exact
public-value exceptions synchronized. It scans all reachable Git history with
redaction and ignores neither inline suppressions nor a supplied ignore file.
The CLI download has a fixed SHA-256 and needs no organization license secret.

Only GitHub can verify event dispatch, fork permissions, SARIF uploads, scheduled
runs, branch protection integration and Dependabot PR creation. Private CodeQL
also depends on the organization's GitHub Code Security entitlement/settings.
Do not describe a locally parsed workflow as a successful hosted run.
