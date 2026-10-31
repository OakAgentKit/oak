# Oak npm package license

The published `@oakagentkit/addon` and `@oakagentkit/core` packages are free to
install and use under the license included in each package's `LICENSE` file.
Their implementation source is private. This page summarizes those terms;
the license shipped with your installed package is authoritative.

## Repository and package boundaries

- **Docs, examples and runtime contracts in this repository:** [MIT](LICENSE).
- **Legacy differential test only:** `contracts/test/OakTickMathDifferential.t.sol` contains a GPL-2.0-or-later Uniswap v3 reference oracle; it is test-only and is never deployed.
- **Core and add-on npm packages:** “Oak — Free to use, no copying.”
- **Hosted Oak service:** private and proprietary; subscription terms are separate.

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
Free package use does not include paid hosted actions. Those require identity
and subscription access once [launch access opens](docs/access-and-pricing.md).
Hosted access is currently limited to the Oak team.

## Warranty and custody

The packages are provided as is, without warranty. See the shipped license
for its liability terms. Read [security](docs/security.md) for the
confirmation and local checks, custody responsibilities and their limits.
Oak is independent and is not affiliated with Robinhood.
