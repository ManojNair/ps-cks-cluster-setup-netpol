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
- Backend accepts ingress from frontend on port 80
- Database accepts ingress from backend on port 5432
- Frontend egress policy (allows connection to backend and DNS)
- Backend egress policy (allows connection to database and DNS)

Let's validate these are working.

### Test 1: Verify Default Deny

First, verify our default deny is blocking traffic. Create a test pod without any special labels:

```bash
kubectl run test-pod --image=nicolaka/netshoot -n production-app -- sleep 3600
```

I'm using netshoot—it's got curl, nc, nslookup, dig, and many other network diagnostic tools we need.

Note: Our frontend and backend pods use nginx, which has limited tools (curl, wget, getent, bash). For comprehensive testing, netshoot is the better choice.

Now try connecting from this test pod to backend service:

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

Using the service name (recommended approach):

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 backend
```

Should succeed. You'll see the nginx welcome page HTML. Policy allowing frontend to backend is working.

Alternative using pod IP:

```bash
BACKEND_IP=$(kubectl get pod backend -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app frontend -- curl --max-time 3 $BACKEND_IP
```

Verify frontend can ONLY connect on port 80:

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 backend:8080
```

Should timeout. Policy only allows port 80. Port restriction working.

### Test 3: Backend to Database

Test backend to database on port 5432.

Using service name (recommended):

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/5432' && echo "Connection successful" || echo "Connection failed"
```

Alternative using pod IP:

```bash
DATABASE_IP=$(kubectl get pod database -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app backend -- timeout 3 bash -c "cat < /dev/null > /dev/tcp/$DATABASE_IP/5432" && echo "Connection successful" || echo "Connection failed"
```

This uses bash's built-in `/dev/tcp` feature to test TCP connectivity. Should see "Connection successful"—connection allowed.

Alternatively, you can test with netcat if available:

```bash
kubectl exec -n production-app backend -- nc -zv -w 3 database 5432
```

Verify backend CANNOT connect on other ports:

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/80' && echo "Connection successful" || echo "Connection failed"
```

Should fail after the 3-second timeout. Only port 5432 allowed.

### Test 4: Verify Isolation - Frontend Cannot Reach Database

An important test: verify that frontend CANNOT directly connect to database. Both the ingress and egress policies should block this:

```bash
kubectl exec -n production-app frontend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/5432' && echo "Connection successful" || echo "Connection failed"
```

Should fail. The database ingress policy only allows connections from backend, and the frontend egress policy only allows connections to backend (not database). This validates our network segmentation is working correctly.

### Summary

We've validated Network Policies with real connectivity tests. The pattern: verify default deny blocks traffic, confirm allowed paths work on correct ports, validate port restrictions, and test that unauthorized paths are blocked.

Key tools: `curl` for HTTP, `/dev/tcp` for TCP port checks, `nslookup` for DNS. Always test both positive cases—what should work—and negative cases—what should be blocked.

For the CKS exam, you need to be comfortable testing policies hands-on. Validation is just as important as creation.

---

**[End of Clip 3]**

---

**[End of Clip 3]**
