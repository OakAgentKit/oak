#!/usr/bin/env bash
set -euo pipefail
config=${1:?Pass the reviewed gitleaks config}
# Full reachable history; checkout must use fetch-depth: 0. Never print values.
gitleaks git . --log-opts=--all --config "$config" --redact \
  --max-archive-depth 2 --max-decode-depth 2 --exit-code 1 \
  --gitleaks-ignore-path "${RUNNER_TEMP:?}/absent-gitleaks-ignore" --ignore-gitleaks-allow
