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

**(Instructional tone)**  
Let's create a test pod with network diagnostic tools:

```bash
kubectl run test-pod --image=nicolaka/netshoot -n production-app -- sleep 3600
```

**(Voiceover)**  
You'll see "pod/test-pod created" in the output.

**(Pause)**  
I'm using the **netshoot** image here—it's a fantastic network troubleshooting container packed with tools like curl, nc, nslookup, dig, tcpdump, and many others.

**(Calm explanation)**  
Now here's the key thing about this test pod—it has **no labels** that match any of our Network Policy selectors.  
It's not labeled `tier=frontend`, `tier=backend`, or `tier=database`.  
This makes it perfect for testing our default deny policy.

Note: Our frontend and backend pods use nginx, which has limited tools (curl, wget, getent, bash). For comprehensive testing, netshoot is the better choice.

**(Instructional tone)**  
Now let's try connecting from this test pod to the backend service:

```bash
kubectl exec -n production-app test-pod -- curl --max-time 3 backend
```

**(Voiceover)**  
You should see curl waiting... and then after 3 seconds, it will timeout with a message like "Connection timed out" or "Failed to connect."

**(Pause for emphasis)**  
This is **exactly** what we want to see.  
The connection is being blocked by our Network Policies.

**(Calm explanation)**  
Here's what's happening under the hood:  
The test-pod tries to connect to the backend service.  
Kubernetes resolves "backend" to the backend pod's IP address.  
The packet reaches the backend pod's network interface.  
But Calico's iptables rules check: "Is this source pod labeled `tier=frontend`?"  
Answer: No. The test-pod has no such label.  
Result: Packet dropped. Connection fails.

**(Pause)**  
This confirms our `backend-allow-frontend` policy is working correctly—it's only allowing connections FROM pods with the frontend label.

**(Instructional tone)**  
Let's test from outside the namespace to verify cross-namespace isolation:

```bash
kubectl run external-test --image=nicolaka/netshoot -n default -- sleep 3600
```

**(Voiceover)**  
This creates a test pod in the **default** namespace—completely outside our production-app namespace.

**(Pause)**  
Now let's try to connect from this external pod:

```bash
kubectl exec -n default external-test -- curl --max-time 3 backend.production-app.svc.cluster.local
```

**(Voiceover)**  
Again, after 3 seconds, this times out and fails.

**(Calm explanation)**  
Notice we're using the fully qualified service name here: `backend.production-app.svc.cluster.local`.  
This is how you reference services across namespaces in Kubernetes.

**(Pause for emphasis)**  
But even with the correct service name, the connection is blocked.  
Why? Because our Network Policies use `podSelector` without a `namespaceSelector`.  
This means they only match pods within the **same namespace**.  
The external-test pod is in the default namespace, so it doesn't match `tier=frontend` in the production-app namespace.

**(Instructional tone)**  
The namespace is completely locked down to external traffic. Perfect.

### Test 2: Frontend to Backend

Now test that frontend CAN connect to backend.

**(Instructional tone)**  
Let's test the legitimate path—frontend to backend—using the service name:

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 backend
```

**(Voiceover)**  
This time, you should immediately see output—the HTML of the nginx welcome page.

**(Pause with satisfaction)**  
Success! The connection worked.

**(Calm explanation)**  
Let's break down why this succeeded:  
First, the **frontend pod's egress policy** allows connections to pods labeled `tier=backend` on port 80.  
Second, the **backend pod's ingress policy** allows connections from pods labeled `tier=frontend` on port 80.  
Both sides agree—egress from frontend is allowed, ingress to backend is allowed.

**(Pause)**  
Also notice—we're using the service name "backend", not an IP address.  
This means DNS resolution is working.  
The frontend pod queried CoreDNS in kube-system, got the backend service's ClusterIP, and connected successfully.  
Our DNS rules in the egress policy are working correctly.

**(Voiceover)**  
You can also test using the pod IP directly instead of the service name:

```bash
BACKEND_IP=$(kubectl get pod backend -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app frontend -- curl --max-time 3 $BACKEND_IP
```

**(Calm explanation)**  
This retrieves the backend pod's IP address using jsonpath, then connects directly to that IP.  
This bypasses DNS resolution and tests the raw IP connectivity.  
Useful when you want to isolate whether a problem is DNS-related or Network Policy-related.

**(Instructional tone)**  
Now let's verify the port restriction—try connecting to the backend on a different port:

```bash
kubectl exec -n production-app frontend -- curl --max-time 3 backend:8080
```

**(Voiceover)**  
This should timeout after 3 seconds and fail to connect.

**(Pause for emphasis)**  
Perfect. This proves our Network Policy is enforcing port-level restrictions.

**(Calm explanation)**  
Our policy explicitly allows TCP port 80—and **only** port 80.  
Even though the frontend is authorized to connect to the backend pod, it can only do so on the allowed port.  
When we try port 8080, Calico's iptables rules check the destination port and drop the packet.

**(Instructional tone)**  
This is critical for security—you're not just controlling WHO can connect, but also WHICH PORTS they can use.  
This limits the attack surface even for authorized connections.

### Test 3: Backend to Database

Test backend to database on port 5432.

**(Instructional tone)**  
Let's test the next layer—backend to database connection.  
We'll use bash's built-in `/dev/tcp` feature since our nginx image doesn't have netcat:

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/5432' && echo "Connection successful" || echo "Connection failed"
```

**(Voiceover)**  
You should see "Connection successful" printed to your terminal.

**(Calm explanation)**  
Let me explain what this command does:  
`/dev/tcp/database/5432` is a special bash feature that opens a TCP connection to the database service on port 5432.  
We're redirecting null input to test if the connection can be established.  
The `timeout 3` ensures we don't wait forever if it fails.  
The `&&` and `||` operators print success or failure based on the exit code.

**(Pause)**  
The connection succeeded because:  
The backend's egress policy allows connections to `tier=database` pods on port 5432.  
The database's ingress policy allows connections from `tier=backend` pods on port 5432.  
Both policies agree—traffic flows successfully.

**(Voiceover)**  
You can also test using the database pod's IP directly:

```bash
DATABASE_IP=$(kubectl get pod database -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app backend -- timeout 3 bash -c "cat < /dev/null > /dev/tcp/$DATABASE_IP/5432" && echo "Connection successful" || echo "Connection failed"
```

**(Calm explanation)**  
This tests direct IP connectivity, bypassing service name resolution.  
Note that Network Policies work at the pod level, not the service level—they filter traffic based on pod labels and IP addresses.  
So whether you use the service name or pod IP, the same Network Policy rules apply.

This uses bash's built-in `/dev/tcp` feature to test TCP connectivity. Should see "Connection successful"—connection allowed.

**(Voiceover)**  
If you have netcat available in your pod, you can use it for cleaner TCP port testing:

```bash
kubectl exec -n production-app backend -- nc -zv -w 3 database 5432
```

**(Calm explanation)**  
The `-z` flag means "scan without sending data", `-v` for verbose output, and `-w 3` sets a 3-second timeout.  
This is more straightforward than the `/dev/tcp` approach, but requires netcat to be installed in the pod.

**(Instructional tone)**  
Let's verify port restrictions at the database level—try connecting on port 80:

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/80' && echo "Connection successful" || echo "Connection failed"
```

**(Voiceover)**  
After 3 seconds, you should see "Connection failed."

**(Pause)**  
Excellent. This confirms our policies are enforcing strict port controls.

**(Calm explanation)**  
The database ingress policy explicitly allows **only** TCP port 5432—the PostgreSQL port.  
Even though the backend pod is authorized to connect to the database, it can only do so on port 5432.  
When we try port 80, the iptables rules drop the connection attempt.

**(Instructional tone)**  
This layered approach—controlling both the source pod AND the destination port—gives you fine-grained security.  
You're implementing the principle of least privilege at the network level.

### Test 4: Verify Isolation - Frontend Cannot Reach Database

An important test: verify that frontend CANNOT directly connect to database. Both the ingress and egress policies should block this:

**(Instructional tone, emphasis)**  
Now for a critical validation—let's verify that frontend CANNOT bypass the backend and connect directly to the database:

```bash
kubectl exec -n production-app frontend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/database/5432' && echo "Connection successful" || echo "Connection failed"
```

**(Voiceover)**  
This should fail and print "Connection failed."

**(Pause for emphasis)**  
This is **crucial**. This proves our network segmentation is actually working.

**(Calm explanation)**  
Why is this connection blocked? There are actually **two** policies preventing it:  

**(Pause)**  
First, the **frontend's egress policy** only allows connections to pods labeled `tier=backend`.  
The database pod is labeled `tier=database`, not `tier=backend`.  
So the frontend isn't authorized to initiate this connection.

**(Pause)**  
Second, the **database's ingress policy** only allows connections from pods labeled `tier=backend`.  
The frontend is labeled `tier=frontend`, not `tier=backend`.  
So even if the frontend tried, the database wouldn't accept the connection.

**(Instructional tone)**  
Both sides are blocking this path. That's defense in depth.  
This validates our three-tier architecture is properly segmented—frontend can only reach backend, backend can only reach database.  
No shortcuts, no direct paths. Exactly what we designed.

### Summary

We've validated Network Policies with real connectivity tests. The pattern: verify default deny blocks traffic, confirm allowed paths work on correct ports, validate port restrictions, and test that unauthorized paths are blocked.

Key tools: `curl` for HTTP, `/dev/tcp` for TCP port checks, `nslookup` for DNS. Always test both positive cases—what should work—and negative cases—what should be blocked.

For the CKS exam, you need to be comfortable testing policies hands-on. Validation is just as important as creation.

---

**[End of Clip 3]**

---

**[End of Clip 3]**
