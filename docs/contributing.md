# Contributing to Arieotech Helm Charts

## Before you start

Read [chart-standards.md](chart-standards.md). Every chart must meet all criteria before merge.

## Local development setup

```bash
# Install chart-testing
brew install helm chart-testing kind

# Install Helm plugins
helm plugin install https://github.com/helm-unittest/helm-unittest

# Lint changed charts
ct lint --config .ct/ct.yaml

# Run against local kind cluster
kind create cluster --config test/kind-cluster/kind-config.yaml
bash test/kind-cluster/bootstrap.sh
ct install --config .ct/ct.yaml
```

## Adding a new chart

1. Create the directory: `charts/<chart-name>/`
2. Use the standard anatomy from [chart-standards.md](chart-standards.md)
3. Add the chart name to `README.md` table
4. Submit a pull request — CI runs `ct lint` + `ct install` automatically

## Reporting bugs in existing charts

Use the [bug report template](../.github/ISSUE_TEMPLATE/bug_report.yaml).
Include the Kubernetes version, cloud provider, and the relevant values excerpt.

## Requesting a new chart

Use the [chart request template](../.github/ISSUE_TEMPLATE/chart_request.yaml).
Explain what is broken or missing in the existing chart, not just that you want a new one.
