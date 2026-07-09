# Changelog

## [0.1.0] - 2026-05-21

### Added
- Initial release — KEDA 2.16.0 CRDs as Helm-managed resources
- ScaledObject CRD (keda.sh/v1alpha1, Namespaced)
- ScaledJob CRD (keda.sh/v1alpha1, Namespaced)
- TriggerAuthentication CRD (keda.sh/v1alpha1, Namespaced)
- ClusterTriggerAuthentication CRD (keda.sh/v1alpha1, Cluster)
- CloudEventSource CRD (eventing.keda.sh/v1alpha1, Namespaced)
- ClusterCloudEventSource CRD (eventing.keda.sh/v1alpha1, Cluster)
- Arieotech fix for upstream issue #5575 (no CRD separation chart)
- README with ArgoCD/GitOps integration guidance
- `helm.sh/resource-policy: keep` annotation and `commonLabels`/`commonAnnotations`
  wiring, applied consistently to all 6 CRDs via a shared `templates/_helpers.tpl`
  (previously only `ScaledObject` had this; the other 5 were unmodified upstream
  manifests, so `helm uninstall` would have deleted them and any live custom
  resources they backed)
- `helm.sh/chart` label now derived from `.Chart.Name`/`.Chart.Version` instead of
  a hardcoded `keda-crds-0.1.0` string that would go stale on every version bump

### Fixed
- `helm.sh/chart` label value wasn't sanitized against Kubernetes label-value rules —
  a `+build` SemVer suffix in `.Chart.Version` would have produced an invalid label
  (`+` isn't a legal label character) with no length cap. Matched
  `arieotech.chart`'s existing `replace "+" "_" | trunc 63 | trimSuffix "-"` pattern.
