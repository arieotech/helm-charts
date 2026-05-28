# GitHub Actions Security Backlog

Items identified during the SHA-pinning pass on 2026-05-28. Review before the next CI iteration.

---

## Done (shipped in this pass)

- [x] All 9 actions SHA-pinned with human-readable version comments
- [x] `aquasecurity/trivy-action@master` → pinned to `v0.36.0` SHA
- [x] `permissions: contents: read` at workflow level as default minimum
- [x] `concurrency:` groups on all 4 workflows (prevents duplicate runs + index.yaml corruption)
- [x] `timeout-minutes:` on every job (prevents runaway billing)
- [x] `--fail-with-body` on `curl` in artifact-hub-sync (was silently succeeding on HTTP errors)
- [x] `.github/dependabot.yml` added — weekly PRs for stale Action SHAs

---

## Backlog

### ~~1. Dependabot for Actions — add `.github/dependabot.yml`~~  ✓ Done

Automatically opens PRs when a new commit SHA exists for a pinned action.
Without this, SHA pins go stale and you run outdated action code indefinitely.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    commit-message:
      prefix: "chore(actions)"
```

**Effort:** 5 minutes. **Value:** Eliminates permanent SHA drift.

---

### 2. Sign OCI charts with cosign

After `helm push` to GHCR, sign the OCI artifact with Sigstore cosign.
Artifact Hub shows a signed badge — matters for enterprise procurement.

```yaml
- name: Install cosign
  uses: sigstore/cosign-installer@<SHA> # add when implementing

- name: Sign OCI chart
  run: |
    cosign sign --yes \
      ghcr.io/arieotech/charts/keycloak:${{ env.CHART_VERSION }}
```

**Effort:** ~1 hour to wire up. **Value:** Trust signal on Artifact Hub, relevant for SOC 2 buyers.

---

### 3. Branch protection rules on `main` (GitHub UI)

Settings → Branches → Add rule for `main`:
- [ ] Require PR before merging
- [ ] Require `lint-test` status check to pass
- [ ] Require linear history
- [ ] Restrict direct pushes to `main`

Without this, a direct push bypasses CI and still triggers the release workflow.

**Effort:** 5 minutes. **Value:** Prevents accidental or malicious bypassing of CI.

---

### 4. OIDC for AWS (when Package A delivery adds cloud interaction to CI)

Replace `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets with OIDC federation.
No long-lived credentials stored in GitHub at all.

```yaml
permissions:
  id-token: write   # needed for OIDC token request
  contents: read

- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@<SHA>
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions
    aws-region: us-east-1
```

**Effort:** ~2 hours (IAM trust policy + workflow update). **Value:** Eliminates static credential exposure risk entirely.

---

### 5. Script injection audit (keep in mind, not urgent)

Rule: never interpolate `${{ github.event.* }}` user-controlled values directly
inside a `run:` step. Use an intermediate `env:` variable instead.

```yaml
# Wrong
run: echo "${{ github.event.pull_request.title }}"

# Correct
env:
  PR_TITLE: ${{ github.event.pull_request.title }}
run: echo "$PR_TITLE"
```

Current workflows have no violations, but apply this rule for any future `run:` steps
that reference event payloads.

---

## Notes

- `pull_request` trigger is safe (runs in fork context with read-only token). Do not switch to `pull_request_target`.
- `GITHUB_ACTOR` in `run:` steps is safe — set by GitHub, not user-controlled input.
- SHA pins must be updated when upgrading an action — always look up the new SHA rather than switching back to a tag.
