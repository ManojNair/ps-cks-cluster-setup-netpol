# Clip 3b: Testing Network Policies - Advanced Validation and Troubleshooting
**Duration:** ~5 minutes

---

## Voiceover Script

Let's go deeper into testing. Beyond basic checks, you need to validate egress policies, inspect policy application, and troubleshoot common issues. This is what separates passing the CKS from really understanding Network Policies.

### Test 1: Egress Policy Validation

Testing egress means checking both what's allowed and what's blocked. Let's validate the backend egress policy.

First, DNS—the most critical part:

```bash
kubectl exec -n production-app backend -- getent hosts kubernetes.default.svc.cluster.local
```

Should work and return an IP address. We allowed UDP and TCP port 53 to kube-system. If this fails, your pods can't resolve service names—super common mistake.

Another way to test DNS resolution:

```bash
kubectl exec -n production-app backend -- getent hosts database
```

This should resolve to the database service IP, confirming DNS is working for internal services.

Note: Don't use curl or wget to test DNS alone—they'll attempt HTTP connections which may be blocked by egress policies even if DNS works. Use `getent hosts` to test pure DNS resolution.

Verify backend CANNOT reach random external destinations:

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/8.8.8.8/53' && echo "Connection successful" || echo "Connection failed"
```

Should fail. Our egress policy only allows connections to database pods and kube-system for DNS, not arbitrary external IPs. Egress isolation working.

You can also test that HTTP connections to external sites are blocked:

```bash
kubectl exec -n production-app backend -- curl --max-time 3 google.com
```

This will timeout because the egress policy doesn't permit connections to external destinations.

Test backend CAN connect to database:

```bash
DATABASE_IP=$(kubectl get pod database -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app backend -- timeout 3 bash -c "cat < /dev/null > /dev/tcp/$DATABASE_IP/5432" && echo "Connection successful" || echo "Connection failed"
```

Should succeed. Egress rule allowing database connections works.

### Test 2: Inspecting Policies

Sometimes you need to see which policies are selecting a pod:

```bash
kubectl describe pod backend -n production-app
```

Look for warnings or events about network policies.

See all policies in a namespace:

```bash
kubectl get networkpolicies -n production-app
```

Get details on a specific policy:

```bash
kubectl describe networkpolicy backend-allow-frontend -n production-app
```

Shows which pods it selects, policy types, all rules. Essential for debugging.

### Test 3: Validating Selectors

Common issue: selectors not matching intended pods. Test them before creating policies:

```bash
kubectl get pods -n production-app -l tier=frontend
```

Shows which pods have that label. If your policy uses this selector, these are the affected pods.

See all labels on a pod:

```bash
kubectl get pod backend -n production-app --show-labels
```

Helps ensure your `matchLabels` exactly match pod labels.

### Troubleshooting Common Issues

**Problem 1: Policy has no effect.**

Check your CNI supports Network Policies:

```bash
kubectl get pods -n kube-system
```

Look for Calico, Cilium, or Weave Net pods. If they're not there or failing, policies won't work.

**Problem 2: DNS fails after egress policies.**

The number one egress mistake. You MUST allow DNS:

```bash
# Example egress rule snippet (add this to every egress policy)
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
```

Include both UDP and TCP on port 53. Add this to every egress policy.

To test DNS, use tools available in your container. For nginx: `getent hosts <hostname>` or `curl <hostname>`. For comprehensive testing, use a netshoot pod which includes nslookup, dig, and other DNS tools.

**Problem 3: Connections work but shouldn't.**

Policies are additive. Check for other policies:

```bash
kubectl get networkpolicies -n production-app -o yaml
```

Review all policies. The union determines what's allowed.

**Problem 4: Selectors don't match.**

Verify labels:

```bash
kubectl get pod <pod-name> -n production-app --show-labels
```

Common mistakes: typos, wrong values, incorrect `matchExpressions`.

### Advanced Testing

For thorough validation:

Create dedicated test pods:

```bash
kubectl run test-client --image=nicolaka/netshoot -n production-app -- sleep 3600
```

Netshoot includes curl, nc, nslookup, dig, and many other network tools—everything you need for comprehensive testing. Keep it running for multiple tests.

Note: The nginx containers used in our demos have limited tools (curl, wget, getent). For more comprehensive DNS testing with tools like nslookup or dig, use netshoot.

Test from different namespaces:

```bash
kubectl run external-test --image=nicolaka/netshoot -n default -- sleep 3600
kubectl exec -n default external-test -- curl backend.production-app.svc.cluster.local
```

Validates namespace isolation.

### Best Practices

Five things for the CKS exam:

1. Test incrementally. One policy at a time. Don't create ten and hope.
2. Test positive AND negative cases. What should work and what should fail.
3. Always test DNS in egress policies. Most common failure.
4. Use descriptive names like `backend-allow-frontend`. Makes debugging easier.
5. Keep test pods ready. Netshoot in different namespaces saves time.

### Cleanup

When done:

```bash
kubectl delete namespace production-app
```

### Summary

Advanced testing is crucial for the CKS exam. You've learned to validate egress, inspect policies with `kubectl describe`, troubleshoot DNS failures and additive conflicts, validate selectors.

Key areas: verify CNI support, always allow DNS in egress, understand additive behavior, check label selectors carefully.

Master testing and troubleshooting, and you'll handle any Network Policy scenario in the exam or production.

---

**[End of Clip 3b]**
