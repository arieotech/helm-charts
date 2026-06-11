#!/usr/bin/env bash
# Create a new chart from the Arieotech standard template.
# Usage: ./scripts/scaffold-chart.sh <chart-name>
set -euo pipefail

CHART_NAME="${1:?Usage: scaffold-chart.sh <chart-name>}"
CHART_DIR="charts/${CHART_NAME}"

if [[ -d "$CHART_DIR" ]]; then
  echo "ERROR: ${CHART_DIR} already exists"
  exit 1
fi

echo "==> Scaffolding ${CHART_DIR}"

mkdir -p "${CHART_DIR}/templates/tests"
mkdir -p "${CHART_DIR}/ci"

# Chart.yaml
cat > "${CHART_DIR}/Chart.yaml" <<EOF
apiVersion: v2
name: ${CHART_NAME}
description: Production-grade ${CHART_NAME} — update this description before publishing
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - ${CHART_NAME}
home: https://github.com/arieotech/helm-charts
sources:
  - https://github.com/arieotech/helm-charts/tree/main/charts/${CHART_NAME}
maintainers:
  - name: Arieotech
    email: helm@arieotech.com
    url: https://arieotech.com
dependencies:
  - name: arieotech-lib
    version: "0.1.0"
    repository: "file://../arieotech-lib"
annotations:
  artifacthub.io/license: Apache-2.0
  artifacthub.io/prerelease: "true"
  artifacthub.io/changes: |
    - kind: added
      description: "Initial release"
EOF

# CHANGELOG
cat > "${CHART_DIR}/CHANGELOG.md" <<EOF
# Changelog

## [0.1.0] - $(date +%Y-%m-%d)

### Added
- Initial release
EOF

# CI default values
cat > "${CHART_DIR}/ci/default-values.yaml" <<EOF
## Minimal working install for ct install testing
## NOT for production use
EOF

echo "==> Created ${CHART_DIR}"
echo ""
echo "Next steps:"
echo "  1. Edit ${CHART_DIR}/Chart.yaml — set description and appVersion"
echo "  2. Create ${CHART_DIR}/values.yaml"
echo "  3. Create ${CHART_DIR}/values.schema.json"
echo "  4. Add templates per chart-standards.md"
echo "  5. Run: ct lint --charts ${CHART_DIR}"
