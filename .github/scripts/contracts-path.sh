#!/usr/bin/env bash
set -euo pipefail
# Both the intended standalone public layout and the existing exporter layout.
for candidate in contracts packages/contracts; do
  if [[ -f "$candidate/foundry.toml" ]]; then
    echo "directory=$candidate" >> "${GITHUB_OUTPUT:?}"
    exit 0
  fi
done
echo '::error::Public contracts are missing: supply contracts/foundry.toml (or packages/contracts/foundry.toml) and its source/tests/dependencies before this check can pass.'
exit 1
