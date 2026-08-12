# Changelog — karpenter-crds

All notable changes to this chart are documented here. This chart follows semantic
versioning independently of the `appVersion` (the Karpenter release the CRDs track).

## 0.1.0

- Initial release.
- Karpenter **1.14.0** CRDs vendored verbatim from upstream
  (`aws/karpenter-provider-aws` `v1.14.0`):
  - `nodepools.karpenter.sh` (v1)
  - `nodeclaims.karpenter.sh` (v1)
  - `nodeoverlays.karpenter.sh` (v1)
  - `ec2nodeclasses.karpenter.k8s.aws` (v1)
  - `capacitybuffers.autoscaling.x-k8s.io` (v1)
- CRDs are Helm-managed (templated labels/annotations only — schemas are byte-for-byte
  upstream) so they can be versioned, upgraded, and rolled back independently of the
  controller. Arieotech fix for ArgoCD CRD drift (upstream
  [#6847](https://github.com/aws/karpenter-provider-aws/issues/6847)).
- `helm.sh/resource-policy: keep` applied by default (`keepCRDs: true`) so
  `helm uninstall` never cascades into deleting live NodePools/NodeClaims and
  deprovisioning nodes.
