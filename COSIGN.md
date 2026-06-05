# Cosign Signature Verification

All Arieotech Helm charts are cryptographically signed using [Cosign](https://docs.sigstore.dev/cosign/) to ensure authenticity, integrity, and supply chain security.

## Overview

Every chart published to `https://charts.arieotech.com` is signed with our private key. The corresponding signature bundle (`.tgz.sig`) is attached to each [GitHub Release](https://github.com/arieotech/helm-charts/releases) alongside the chart archive. Verification confirms:

- **Authenticity** — the chart was published by Arieotech
- **Integrity** — the chart has not been tampered with since it was signed
- **Supply chain security** — end-to-end provenance from source to install

## Public Key

All charts are signed with the following Cosign public key:

**Download:** [cosign.pub](https://raw.githubusercontent.com/arieotech/helm-charts/main/cosign.pub)

```
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhJynJ8YvPiUfKlW7uAXGnbeMG0KU
zLQzm305ZVp4g3j6FZsYJfqmSL4Ow5i9mjaGGRiw93MbP03ghDe9g8roiQ==
-----END PUBLIC KEY-----
```

## Prerequisites

Install Cosign on your system:

```bash
# macOS
brew install cosign

# Linux
curl -sSL \
  "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Windows
winget install sigstore.cosign
```

Or see the [official installation guide](https://docs.sigstore.dev/cosign/system_config/installation/).

## Verifying a Chart

### Step 1 — Get the public key

```bash
curl -sL \
  https://raw.githubusercontent.com/arieotech/helm-charts/main/cosign.pub \
  -o cosign.pub
```

### Step 2 — Pull the chart

```bash
helm repo add arieotech https://charts.arieotech.com
helm repo update
helm pull arieotech/<chart-name> --version <version>
# e.g.
helm pull arieotech/keycloak --version 0.3.2
```

This downloads `<chart-name>-<version>.tgz` to your current directory.

### Step 3 — Download the signature bundle

Each chart's `.sig` bundle is attached to its GitHub Release:

```bash
curl -sL \
  "https://github.com/arieotech/helm-charts/releases/download/<chart-name>-<version>/<chart-name>-<version>.tgz.sig" \
  -o "<chart-name>-<version>.tgz.sig"
# e.g.
curl -sL \
  "https://github.com/arieotech/helm-charts/releases/download/keycloak-0.3.2/keycloak-0.3.2.tgz.sig" \
  -o "keycloak-0.3.2.tgz.sig"
```

### Step 4 — Verify

```bash
cosign verify-blob \
  --key cosign.pub \
  --bundle <chart-name>-<version>.tgz.sig \
  <chart-name>-<version>.tgz
# e.g.
cosign verify-blob \
  --key cosign.pub \
  --bundle keycloak-0.3.2.tgz.sig \
  keycloak-0.3.2.tgz
```

**Successful output:**

```
Verified OK
```

Any other output or non-zero exit code means the archive has been tampered with or was signed with a different key. **Do not install it.**

## Verify-Before-Install Pattern

A complete pull-verify-install sequence:

```bash
# 1. Add the repo
helm repo add arieotech https://charts.arieotech.com
helm repo update

# 2. Get the public key
curl -sL \
  https://raw.githubusercontent.com/arieotech/helm-charts/main/cosign.pub \
  -o cosign.pub

# 3. Pull the chart archive
helm pull arieotech/keycloak --version 0.3.2

# 4. Download the signature bundle
curl -sL \
  https://github.com/arieotech/helm-charts/releases/download/keycloak-0.3.2/keycloak-0.3.2.tgz.sig \
  -o keycloak-0.3.2.tgz.sig

# 5. Verify — abort if this fails
cosign verify-blob \
  --key cosign.pub \
  --bundle keycloak-0.3.2.tgz.sig \
  keycloak-0.3.2.tgz

# 6. Install only after verification succeeds
helm upgrade --install keycloak arieotech/keycloak \
  --version 0.3.2 \
  --namespace keycloak \
  --create-namespace
```

## CI Pipeline Integration

Add a verification gate to your pipeline before deploying:

```bash
#!/usr/bin/env bash
set -euo pipefail

CHART="keycloak"
VERSION="0.3.2"
REPO="https://charts.arieotech.com"
PUBKEY_URL="https://raw.githubusercontent.com/arieotech/helm-charts/main/cosign.pub"

# Install cosign if not present
command -v cosign >/dev/null 2>&1 || {
  curl -sSL \
    "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" \
    -o /usr/local/bin/cosign
  chmod +x /usr/local/bin/cosign
}

# Fetch key, chart, and signature bundle
curl -sL "$PUBKEY_URL" -o cosign.pub
helm repo add arieotech "$REPO" --force-update
helm pull "arieotech/${CHART}" --version "$VERSION"
curl -sL \
  "https://github.com/arieotech/helm-charts/releases/download/${CHART}-${VERSION}/${CHART}-${VERSION}.tgz.sig" \
  -o "${CHART}-${VERSION}.tgz.sig"

# Verify — pipeline fails here if signature is invalid
cosign verify-blob \
  --key cosign.pub \
  --bundle "${CHART}-${VERSION}.tgz.sig" \
  "${CHART}-${VERSION}.tgz"

echo "Signature verified — proceeding with deployment"
```

## GitHub Actions Integration

```yaml
- name: Verify Helm chart signature
  run: |
    curl -sL \
      https://raw.githubusercontent.com/arieotech/helm-charts/main/cosign.pub \
      -o cosign.pub
    helm pull arieotech/${{ env.CHART }} --version ${{ env.VERSION }}
    curl -sL \
      "https://github.com/arieotech/helm-charts/releases/download/${{ env.CHART }}-${{ env.VERSION }}/${{ env.CHART }}-${{ env.VERSION }}.tgz.sig" \
      -o "${{ env.CHART }}-${{ env.VERSION }}.tgz.sig"
    cosign verify-blob \
      --key cosign.pub \
      --bundle "${{ env.CHART }}-${{ env.VERSION }}.tgz.sig" \
      "${{ env.CHART }}-${{ env.VERSION }}.tgz"
```

## Artifact Hub

Arieotech charts are listed on [Artifact Hub](https://artifacthub.io/packages/search?org=arieotech&sort=relevance). The **Signed** badge on each package listing confirms the chart has a valid Cosign signature verified against the public key above.

## Additional Resources

- [Sigstore / Cosign documentation](https://docs.sigstore.dev/cosign/)
- [Cosign installation](https://docs.sigstore.dev/cosign/system_config/installation/)
- [Arieotech Helm charts](https://charts.arieotech.com)
- [GitHub Releases](https://github.com/arieotech/helm-charts/releases)
- [SLSA supply chain security levels](https://slsa.dev/)
