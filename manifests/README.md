# Network Policy Manifests

This directory contains validated Kubernetes Network Policy YAML manifests extracted from the tutorial content.

## Files

### Ingress Policies (from Clip2.md)

- **default-deny-ingress.yaml** - Denies all ingress traffic to all pods in the namespace
- **backend-allow-frontend.yaml** - Allows frontend pods to connect to backend pods on port 80
- **database-allow-backend.yaml** - Allows backend pods to connect to database pods on port 3306

### Egress Policies (from Clip2b.md)

- **backend-allow-egress.yaml** - Controls outbound traffic from backend pods
  - Allows connections to database pods on TCP 3306
  - Allows DNS queries to kube-system on UDP 53
- **frontend-allow-external-api.yaml** - Allows frontend pods to connect to external APIs
  - Uses ipBlock to allow connections to 203.0.113.0/24
  - Excludes 203.0.113.1/32 from the allowed range

## Usage

### Prerequisites

1. A Kubernetes cluster
2. A CNI plugin that supports Network Policies (Calico, Cilium, or Weave Net)
3. kubectl configured to access your cluster

### Setup

```bash
# Create the namespace
kubectl create namespace production-app

# Create test pods
kubectl run frontend --image=nginx --labels=tier=frontend -n production-app
kubectl run backend --image=nginx --labels=tier=backend -n production-app
kubectl run database --image=nginx --labels=tier=database -n production-app
```

### Apply Policies

Apply policies in this order for best results:

```bash
# 1. Apply default deny (locks everything down)
kubectl apply -f manifests/default-deny-ingress.yaml

# 2. Apply ingress allow policies (selectively opens access)
kubectl apply -f manifests/backend-allow-frontend.yaml
kubectl apply -f manifests/database-allow-backend.yaml

# 3. Apply egress policies (controls outbound traffic)
kubectl apply -f manifests/backend-allow-egress.yaml
```

### Verify

```bash
# List all network policies
kubectl get networkpolicies -n production-app

# Describe a specific policy
kubectl describe networkpolicy backend-allow-frontend -n production-app

# View detailed YAML
kubectl get networkpolicies -n production-app -o yaml
```

## Validation Status

✅ All manifests have been validated against Kubernetes v1.34.0

See [VALIDATION_REPORT.md](../VALIDATION_REPORT.md) for detailed test results.

## Notes

- These policies are namespace-scoped and only affect the `production-app` namespace
- Network Policies are additive - multiple policies selecting the same pod combine their rules
- The egress policy for backend includes DNS (UDP 53 to kube-system) - this is critical!
- Without DNS in egress policies, pods cannot resolve service names

## Testing

For testing these policies, see the commands in:
- [Clip3.md](../Clip3.md) - Basic validation
- [Clip3b.md](../Clip3b.md) - Advanced validation and troubleshooting
