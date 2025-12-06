#!/usr/bin/env bash
set -euo pipefail

########################################
# Tools: kind v0.30.0 + kubectl v1.34.0
########################################

# kind
curl -L https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64 -o kind
chmod +x kind
sudo mv kind /usr/local/bin/kind

# kubectl (explicit v1.34.0 to match CKS exam)
curl -L "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl" -o kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

########################################
# KIND cluster (Kubernetes v1.34.0)
########################################

cat > kind-config.yaml << 'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
  - role: control-plane
    image: kindest/node:v1.34.0@sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a
  - role: worker
    image: kindest/node:v1.34.0@sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a
YAML

kind create cluster --name np-lab --config kind-config.yaml

########################################
# CNI with NetworkPolicy support (Calico)
########################################

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml

# wait & verify
echo "Waiting for Calico pods..."
kubectl -n kube-system wait --for=condition=Ready pods --all --timeout=180s
kubectl -n kube-system get pods
