#!/usr/bin/env bash
# Bootstrap cluster prerequisites before ct install runs.
# Called by lint-test.yaml CI workflow.
set -euo pipefail

echo "==> Installing cert-manager (required by some charts)"
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 120s

echo "==> Installing Prometheus Operator CRDs (required for ServiceMonitor/PrometheusRule)"
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml

echo "==> Deploying PostgreSQL for Keycloak CI testing (namespace: keycloak-ci-db)"
kubectl create namespace keycloak-ci-db --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak-postgresql
  namespace: keycloak-ci-db
  labels:
    app: keycloak-postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak-postgresql
  template:
    metadata:
      labels:
        app: keycloak-postgresql
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_DB
              value: keycloak
            - name: POSTGRES_USER
              value: keycloak
            - name: POSTGRES_PASSWORD
              value: changeme-ci-only
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "keycloak"]
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-postgresql
  namespace: keycloak-ci-db
spec:
  selector:
    app: keycloak-postgresql
  ports:
    - port: 5432
      targetPort: 5432
EOF

echo "==> Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=available --timeout=90s deployment/keycloak-postgresql -n keycloak-ci-db

echo "==> Pre-applying KEDA CRDs (required by keda chart CI — operator crashes without them)"
# Apply via kubectl so there is no Helm release ownership conflict when ct install
# subsequently tests the keda-crds chart using helm upgrade --install.
for crd in charts/keda-crds/templates/crds/*.yaml; do
  kubectl apply --server-side -f "$crd"
done

echo "==> Bootstrap complete"
