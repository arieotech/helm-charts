#!/usr/bin/env bash
# Run ct lint against all charts locally.
# Usage: ./scripts/validate-all.sh
set -euo pipefail

ct lint --config .ct/ct.yaml --all
