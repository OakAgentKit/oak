#!/usr/bin/env bash
set -euo pipefail
# The standalone public tree has one authoritative contract project.
[[ -f contracts/foundry.toml ]] || {
  echo '::error::Authoritative public contracts are missing: contracts/foundry.toml is required.'
  exit 1
}
echo 'directory=contracts' >> "${GITHUB_OUTPUT:?}"
