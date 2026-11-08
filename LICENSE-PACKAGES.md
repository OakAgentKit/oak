# Oak npm package license

The published `@oakagentkit/addon` and `@oakagentkit/core` packages are free to
install and use under the license included in each package's `LICENSE` file.
Their implementation source is private. This page summarizes those terms;
the license shipped with your installed package is authoritative.

## Repository and package boundaries

- **Docs, examples and runtime contracts in this repository:** [MIT](LICENSE).
- **Legacy differential test only:** `contracts/test/OakTickMathDifferential.t.sol` contains a GPL-2.0-or-later Uniswap v3 reference oracle; it is test-only and is never deployed.
- **Install plugin files and the `oak-recipe/v1` recipe format/schema:** MIT. The plugin includes its own MIT LICENSE; the recipe schema carries its MIT license note.
- **Core and add-on npm packages:** “Oak — Free to use, no copying.”
- **Agent Wormhole text scanner introduced in 0.2.6:** Apache-2.0, with its license and upstream attribution included in the compiled packages; see [Agent Wormhole](https://github.com/runningoffcode/agent-wormhole). Oak's package terms do not replace that license.
- **Hosted Oak service:** private and proprietary; Oak is free to use and earns a 0.25% fee on swaps and bridges, plus partner referral fees.
- **Independence:** Oak is not affiliated with Robinhood.

No recipe package ships in this repository. Your own examples and data-only
recipes can invoke the official npm packages as dependencies.

## Permitted use

You may install and run the official packages on your machines, including in
your own agents and commercial products, without a licensing charge.
You may make copies technically necessary to install, run and back up the
packages for that use. Keep the package license with permitted copies.

Normal setup uses `oak mcp` and creates a local wallet automatically.
Wallet initialization and key export are owner-terminal operations, not
agent setup steps. See [client setup](docs/client-setup/README.md).

## Copying and distribution

The package license does not otherwise permit copying, modification,
distribution, resale, sublicensing or rehosting of the package code,
whether original, minified or derived.
A product may depend on the official package; that does not permit
redistributing its code inside another package, bundle, service download
or hosted mirror. The license grants no trademark rights.

## Dependencies and service access

Third-party dependencies are separate works governed by their own licenses.
Oak's package terms do not replace those terms.
Oak is free to use. Hosted actions require a verified ERC-8004 identity (except the free `gloam_claim` action). See [access and pricing](docs/access-and-pricing.md).

## Warranty and custody

The packages are provided as is, without warranty. See the shipped license
for its liability terms. Read [security](docs/security.md) for the
confirmation and local checks, custody responsibilities and their limits.

## Optional Gloam engine

`@oakagentkit/gloam@0.3.3` is installed separately beside the add-on; it is not an add-on dependency. Its package LICENSE uses the same Oak license text as the add-on, as directed by the owner before publication. Its SDK and proving dependency graph includes GPL-3.0 packages (including snarkjs, circomlibjs and ffjavascript); their own licenses continue to apply. Core and the add-on do not import the SDK or snarkjs.
