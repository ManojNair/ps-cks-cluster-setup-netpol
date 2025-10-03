# Clip 3: Testing Network Policies - Basic Validation
**Duration:** ~5 minutes

---

## Voiceover Script

Time to test Network Policies. You need to verify they're actually doing what you think they're doing. For the CKS exam, you'll create policies and validate them, maybe troubleshoot broken ones. Let's walk through how to test these properly.

### Why Testing Matters

Network Policies are declarative—you write what you want, the CNI enforces it. But there's a gap between intent and reality. Maybe you typo'd a label. Maybe you forgot DNS. Maybe your CNI isn't configured right. Testing is the only way to know for sure.

### Demo Setup

We've got a namespace called `production-app` with three pods: frontend, backend, and database. We've applied several policies:
- Default deny ingress
- Frontend can connect to backend on port 80
- Backend can connect to database on port 3306
- Egress policy for backend

Let's validate these are working.

### Test 1: Verify Default Deny

First, verify our default deny is blocking traffic. Create a test pod without any special labels:

```bash
kubectl run test-pod --image=nicolaka/netshoot -n production-app -- sleep 3600
```

I'm using netshoot—it's got curl, nc, nslookup, all the tools we need.

Now try connecting from this test pod to backend:

```bash
kubectl exec -n production-app test-pod -- curl --max-time 3 backend
```

Should timeout. The test pod doesn't have `tier=frontend`, so it can't connect. Default deny is working.

Let's test from outside the namespace:

```bash
kubectl run external-test --image=nicolaka/netshoot -n default -- sleep 3600
kubectl exec -n default external-test -- curl --max-time 3 backend.production-app.svc.cluster.local
```

Also times out. Namespace is locked down.

### Test 2: Frontend to Backend

Now test that frontend CAN connect to backend.

Get the backend IP:

```bash
BACKEND_IP=$(kubectl get pod backend -n production-app -o jsonpath='{.status.podIP}')
echo $BACKEND_IP
```

Exec into frontend and try connecting:

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 $BACKEND_IP
```

Should succeed. You'll see the nginx welcome page HTML. Policy allowing frontend to backend is working.

Verify frontend can ONLY connect on port 80:

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 $BACKEND_IP:8080
```

Should timeout. Policy only allows port 80. Port restriction working.

### Test 3: Backend to Database

Test backend to database on port 3306.

```bash
DATABASE_IP=$(kubectl get pod database -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app backend -- nc -zv $DATABASE_IP 3306
```

`-z` means zero-I/O mode, just scanning. `-v` is verbose. Should see "succeeded" or "open"—connection allowed.

Verify backend CANNOT connect on other ports:

```bash
kubectl exec -n production-app backend -- nc -zv -w 3 $DATABASE_IP 80
```

`-w 3` is a 3-second timeout. Should fail. Only port 3306 allowed.

### Summary

We've validated Network Policies with real connectivity tests. The pattern: verify default deny blocks traffic, confirm allowed paths work on correct ports, validate port restrictions.

Key tools: `curl` for HTTP, `nc` for TCP port checks, `nslookup` for DNS. Always test both positive cases—what should work—and negative cases—what should be blocked.

For the CKS exam, you need to be comfortable testing policies hands-on. Validation is just as important as creation.

---

**[End of Clip 3]**

---

**[End of Clip 3]**
