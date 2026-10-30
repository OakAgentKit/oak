#!/usr/bin/env bash
set -euo pipefail
# Provision once online; subsequent forge build/test run with --offline.
solc="${RUNNER_TEMP:?}/solc-0.8.26"
curl --fail --silent --show-error --location --retry 3 \
  'https://raw.githubusercontent.com/ethereum/solc-bin/gh-pages/linux-amd64/solc-linux-amd64-v0.8.26+commit.8a97fa7a' \
  --output "$solc"
echo "d5f23436f443edb85d8e76906d12f0a86ce0490e7663a9e608efeb7a93f149ef  $solc" > "$solc.sha256"
sha256sum -c "$solc.sha256"
chmod 755 "$solc"
echo "OAK_CI_SOLC=$solc" >> "${GITHUB_ENV:?}"
