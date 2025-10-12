# Clip 2b: Creating Network Policies - Egress Rules and IP Blocks
**Duration:** ~5 minutes

---

## Voiceover Script

Now let's talk egress—controlling where your pods can connect TO. This is just as important as ingress, and there's one thing you absolutely have to get right: DNS.

### Demo Context

We're continuing with our three-tier app in `production-app`: frontend, backend, and database. We've secured incoming traffic. Time to control outgoing.

### Egress Policy with DNS Support

Here's the scenario: we want to control where backend can connect TO.

```bash
cat << EOF > backend-allow-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-egress
  namespace: production-app
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
```

`policyTypes: - Egress`—we're controlling outbound traffic. Once you specify this, the pod becomes isolated for egress. Only explicitly allowed connections work.

`egress:`—this lists allowed outbound connections.

First rule: `to: - podSelector: matchLabels: tier: database`—backend can connect TO database pods on TCP 5432. The `to` field is like `from` but reversed.

Second rule—and this is critical—DNS. We're allowing connections to kube-system on UDP port 53.

`namespaceSelector: matchLabels: kubernetes.io/metadata.name: kube-system`—targets the entire kube-system namespace where CoreDNS runs.

Why is DNS so important? Without it, your pods can't resolve domain names. They'll fail to connect to services even if you allow the IPs. Always include DNS in egress policies. I can't stress this enough—it's the most common mistake people make.

```bash
kubectl apply -f backend-allow-egress.yaml
```

Now backend can only reach database and DNS. No external internet, no other services.

### Using IP Blocks for External APIs

Sometimes you need to allow traffic to external IPs outside your cluster. Say our frontend needs to call an external payment API at 203.0.113.0/24.

```bash
cat << EOF > frontend-allow-external-api.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-external-api
  namespace: production-app
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 203.0.113.0/24
        except:
        - 203.0.113.1/32
    ports:
    - protocol: TCP
      port: 443
EOF
```

`ipBlock: cidr: 203.0.113.0/24`—instead of pod or namespace selectors, we're using an IP range. This allows traffic to that entire /24. Use this for external services, cloud APIs, anything outside Kubernetes.

`except: - 203.0.113.1/32`—this carves out exceptions. We're allowing the /24 EXCEPT for .1. Maybe that's a compromised host or a restricted endpoint.

```bash
kubectl apply -f frontend-allow-external-api.yaml
```

### Combining Selectors

You can combine namespace and pod selectors. Here's backend connecting to Prometheus in a monitoring namespace:

```bash
# Example egress rule snippet (add this to a policy's egress section)
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: monitoring
    podSelector:
      matchLabels:
        app: prometheus
  ports:
  - protocol: TCP
    port: 9090
```

Both selectors under the same `to` entry means "pods labeled app=prometheus IN namespaces labeled name=monitoring." If you separate them, it means "prometheus pods anywhere OR any pod in monitoring"—totally different.

### Critical Points

Three things to remember about egress:

Once you add Egress to policyTypes, that pod is isolated for egress. Only explicitly allowed connections work.

Always include DNS. UDP port 53 to kube-system in every egress policy.

For a connection to work, both sides must agree. Source's egress AND destination's ingress both need to allow it.

### Summary

You've learned egress policies and IP blocks—the tools for controlling outbound traffic. Egress rules use `to` instead of `from`. You can target pods, namespaces, or external IP ranges.

The pattern: when you create egress policies, always include DNS. Use `namespaceSelector` for cross-namespace communication. Use `ipBlock` for external services.

Mastering both ingress and egress gives you complete network isolation control—critical for the CKS exam and production security.

---

**[End of Clip 2b]**
