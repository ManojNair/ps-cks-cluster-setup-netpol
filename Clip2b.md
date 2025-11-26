# Clip 2b: Creating Network Policies - Egress Rules and IP Blocks
**Duration:** ~5 minutes

---

## Voiceover Script

Now let's talk egress—controlling where your pods can connect TO. This is just as important as ingress, and there's one thing you absolutely have to get right: DNS.

### Demo Context

We're continuing with our three-tier app in `production-app`: frontend, backend, and database. We've secured incoming traffic. Time to control outgoing.

### Frontend Egress Policy

Before we look at the backend, let's create an egress policy for the frontend. The frontend needs to connect to the backend service on port 80, and of course, it needs DNS.

```bash
cat << EOF > frontend-allow-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-egress
  namespace: production-app
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 80
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

This policy allows the frontend to:
1. Connect to backend pods on TCP port 80
2. Resolve DNS queries via kube-system

**(Instructional tone)**  
Let's apply this egress policy:

```bash
kubectl apply -f frontend-allow-egress.yaml
```

**(Voiceover)**  
You'll see "networkpolicy/frontend-allow-egress created" in your output.

**(Pause for emphasis)**  
So what just happened?  
The moment we applied this policy with `policyTypes: Egress`, the frontend pod became **isolated for egress traffic**.  
This means it can no longer make ANY outbound connections except what we explicitly allow.

**(Calm explanation)**  
Calico has updated the iptables rules on the node where the frontend pod runs.  
Now the frontend can ONLY:
- Connect to pods labeled `tier=backend` on TCP port 80
- Send DNS queries to kube-system on UDP and TCP port 53

**(Pause)**  
Everything else is blocked.  
The frontend can't reach the internet, can't connect to other namespaces, can't even ping other pods in the same namespace.  
Only backend on port 80, and DNS. That's it.

### Backend Egress Policy with DNS Support

Now let's control where backend can connect TO.

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
    - protocol: TCP
      port: 53
EOF
```

`policyTypes: - Egress`—we're controlling outbound traffic. Once you specify this, the pod becomes isolated for egress. Only explicitly allowed connections work.

`egress:`—this lists allowed outbound connections.

First rule: `to: - podSelector: matchLabels: tier: database`—backend can connect TO database pods on TCP 5432. The `to` field is like `from` but reversed.

Second rule—and this is critical—DNS. We're allowing connections to kube-system on UDP port 53.

`namespaceSelector: matchLabels: kubernetes.io/metadata.name: kube-system`—targets the kube-system namespace where CoreDNS runs.

Note: In Kubernetes 1.22+, the kube-system namespace is automatically labeled with `kubernetes.io/metadata.name: kube-system`. However, if you're on an older cluster or this label doesn't exist, you can also use `name: kube-system` or manually label the namespace.

Why is DNS so important? Without it, your pods can't resolve domain names. They'll fail to connect to services even if you allow the IPs. Always include DNS in egress policies. I can't stress this enough—it's the most common mistake people make.

**(Instructional tone)**  
Alright, let's apply this backend egress policy:

```bash
kubectl apply -f backend-allow-egress.yaml
```

**(Voiceover)**  
You should see "networkpolicy/backend-allow-egress created" confirming the policy is active.

**(Pause)**  
Now our backend pod is also isolated for egress.  
Here's what's interesting—we now have **both ingress AND egress** policies working together.

**(Calm explanation)**  
For ingress, we have `backend-allow-frontend` which allows the frontend to connect IN to the backend.  
For egress, we just applied `backend-allow-egress` which allows the backend to connect OUT to the database.

**(Pause for clarity)**  
Think about the complete traffic flow:  
Frontend can connect OUT to backend (frontend's egress allows it).  
Backend can accept IN from frontend (backend's ingress allows it).  
Backend can connect OUT to database (backend's egress allows it).  
Database can accept IN from backend (database's ingress allows it).

**(Instructional tone)**  
Both sides of every connection must agree—that's how Network Policies work.  
And critically, both frontend and backend can still do DNS resolution because we explicitly allowed it.  
Without those DNS rules, service name resolution would fail, even though the IP connectivity would be allowed.

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
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

`ipBlock: cidr: 203.0.113.0/24`—instead of pod or namespace selectors, we're using an IP range. This allows traffic to that entire /24. Use this for external services, cloud APIs, anything outside Kubernetes.

`except: - 203.0.113.1/32`—this carves out exceptions. We're allowing the /24 EXCEPT for .1. Maybe that's a compromised host or a restricted endpoint.

Notice we also included DNS in this egress policy. Remember—every time you create an egress policy, you need to allow DNS to kube-system. Without it, your pods can't resolve domain names, and they'll fail to connect even to internal services.

**(Instructional tone)**  
Let's apply this policy to allow external API access:

```bash
kubectl apply -f frontend-allow-external-api.yaml
```

**(Voiceover)**  
You'll see "networkpolicy/frontend-allow-external-api created" in the output.

**(Pause)**  
Now this is important—what happens when we apply a second egress policy to the same pod?

**(Calm explanation)**  
Remember, Network Policies use **OR** logic.  
We already have `frontend-allow-egress` allowing connections to backend and DNS.  
Now we've added `frontend-allow-external-api` allowing connections to 203.0.113.0/24 on port 443, plus DNS.

**(Pause for emphasis)**  
Kubernetes combines these policies.  
The frontend pod can now make ALL connections allowed by ANY matching policy:  
- Backend on port 80 (from the first policy)  
- External API at 203.0.113.0/24 on port 443 (from this new policy)  
- Except 203.0.113.1 specifically (carved out by the `except` clause)  
- And DNS to kube-system (allowed by both policies)

**(Instructional tone)**  
This is how you build granular egress controls—layer multiple policies, each authorizing specific traffic patterns.  
Calico translates all of these into a unified set of iptables rules that permit exactly this traffic and nothing more.

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

Four things to remember about egress:

Once you add Egress to policyTypes, that pod is isolated for egress. Only explicitly allowed connections work.

Always include DNS. Both UDP and TCP port 53 to kube-system in every egress policy. DNS primarily uses UDP, but large responses may require TCP.

For a connection to work, both sides must agree. Source's egress AND destination's ingress both need to allow it. You need complementary policies on both ends.

Think of it like a door with locks on both sides—you need keys for both locks. The frontend's egress policy must allow connecting to backend, AND the backend's ingress policy must allow connections from frontend.

### Summary

You've learned egress policies and IP blocks—the tools for controlling outbound traffic. Egress rules use `to` instead of `from`. You can target pods, namespaces, or external IP ranges.

The pattern: when you create egress policies, always include DNS on both UDP and TCP port 53. Use `namespaceSelector` for cross-namespace communication. Use `ipBlock` for external services.

Remember: create complementary egress and ingress policies. For frontend to reach backend, you need the frontend's egress policy allowing connections to backend AND the backend's ingress policy allowing connections from frontend.

Mastering both ingress and egress gives you complete network isolation control—critical for the CKS exam and production security.

---

**[End of Clip 2b]**
