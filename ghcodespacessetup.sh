# tools
curl -L https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64 -o kind && chmod +x kind && sudo mv kind /usr/local/bin/kind
curl -L https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl -o kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl

# cluster
cat > kind-config.yaml << 'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
YAML

kind create cluster --name np-lab --config kind-config.yaml

# CNI with NetworkPolicy support
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml

# wait & verify
kubectl -n calico-system get pods