# Clip 2: Creating Network Policies - Ingress Rules
**Duration:** ~5 minutes

---

## Voiceover Script

Let's get hands-on and actually create some Network Policies. We'll work through real scenarios, and I'll walk you through the YAML piece by piece so you understand what each part does.

### Demo Setup

You'll need a cluster with a CNI that supports Network Policies—Calico, Cilium, Weave Net, whatever you've got. Let's set up a simple three-tier app: frontend, backend, and database.

```bash
kubectl create namespace production-app

kubectl run frontend --image=nginx --labels=tier=frontend -n production-app
kubectl run backend --image=nginx --labels=tier=backend -n production-app
kubectl run database --image=nginx --labels=tier=database -n production-app
```

Right now? Everything can talk to everything. Let's lock that down.

### Example 1: Default Deny Ingress Policy

Best practice: deny everything first, then open up what you need. Let's start there.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Let me break this down. `apiVersion` is `networking.k8s.io/v1`—that's been stable since Kubernetes 1.7, so you'll always use this.

`metadata`—standard stuff. Name and namespace. Remember, policies are namespaced, so this only affects `production-app`.

Now the spec. `podSelector: {}`—those empty curly braces? That means "select ALL pods in this namespace." Super important pattern.

`policyTypes: - Ingress`—we're defining ingress rules. Egress is still unrestricted.

Here's the trick though. We specified Ingress in policyTypes, but we didn't define any actual ingress rules. No rules means no traffic allowed. That's what makes this deny-all.

```bash
kubectl apply -f default-deny-ingress.yaml
```

Now everything's isolated for ingress. Pods can't receive connections from anything. But they can still make outbound connections since we didn't touch egress.

### Example 2: Allow Frontend to Backend

Okay, we've locked everything down. Now let's open a specific path—frontend to backend on port 80.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: production-app
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
```

`podSelector` with `matchLabels: tier: backend`—this policy only applies to backend pods. Unlike the previous one, this is specific.

`ingress: - from:`—here's our list of allowed incoming connections.

`podSelector: matchLabels: tier: frontend`—allow connections from pods labeled `tier=frontend`. No namespaceSelector here, so it only matches pods in the same namespace.

`ports: protocol: TCP, port: 80`—TCP port 80 specifically. Always be explicit with ports.

```bash
kubectl apply -f backend-allow-frontend.yaml
```

Now frontend can connect to backend on port 80. Nothing else can.

### Example 3: Allow Backend to Database

Let's allow backend to reach the database on port 3306.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-allow-backend
  namespace: production-app
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 3306
```

Should look familiar now. Selecting database pods, allowing ingress from backend on TCP 3306.

```bash
kubectl apply -f database-allow-backend.yaml
```

### Summary

So we've covered the core ingress pattern: default deny everything, then selectively allow specific pod-to-pod communication on specific ports.

Key elements: `podSelector` picks which pods the policy affects. `policyTypes` says ingress or egress. The `ingress` rules define who can connect using `podSelector` and `ports`.

This deny-by-default approach is fundamental for Kubernetes security. You've now seen how to lock down incoming traffic and open just what you need. Essential stuff for the CKS exam.

---

**[End of Clip 2]**
