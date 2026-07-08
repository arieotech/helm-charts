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
