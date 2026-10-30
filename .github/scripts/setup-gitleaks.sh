#!/usr/bin/env bash
set -euo pipefail
# Linux x64 GitHub runner; fixed version and release checksum, no license secret.
work=$(mktemp -d "${RUNNER_TEMP:?}/oak-gitleaks.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
curl --fail --silent --show-error --location --retry 3 \
  https://github.com/gitleaks/gitleaks/releases/download/v8.30.0/gitleaks_8.30.0_linux_x64.tar.gz \
  --output "$work/gitleaks.tar.gz"
echo "79a3ab579b53f71efd634f3aaf7e04a0fa0cf206b7ed434638d1547a2470a66e  $work/gitleaks.tar.gz" > "$work/checksums"
sha256sum -c "$work/checksums"
mkdir -p "${RUNNER_TEMP}/oak-bin"
tar -xzf "$work/gitleaks.tar.gz" -C "${RUNNER_TEMP}/oak-bin" gitleaks
echo "${RUNNER_TEMP}/oak-bin" >> "${GITHUB_PATH:?}"
