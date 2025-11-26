# Clip 3b: Testing Network Policies - Advanced Validation and Troubleshooting
**Duration:** ~5 minutes

---

## Voiceover Script

Let's go deeper into testing. Beyond basic checks, you need to validate egress policies, inspect policy application, and troubleshoot common issues. This is what separates passing the CKS from really understanding Network Policies.

### Test 1: Egress Policy Validation

Testing egress means checking both what's allowed and what's blocked. Let's validate the backend egress policy.

First, DNS—the most critical part:

**(Instructional tone)**  
Let's test DNS resolution from the backend pod:

```bash
kubectl exec -n production-app backend -- getent hosts kubernetes.default.svc.cluster.local
```

**(Voiceover)**  
You should see output showing an IP address, something like: `10.96.0.1 kubernetes.default.svc.cluster.local`

**(Pause)**  
Perfect. DNS is working.

**(Calm explanation)**  
`getent hosts` is a perfect tool for testing DNS resolution because it **only** tests name resolution—it doesn't attempt any actual connection.  
This command queries CoreDNS in the kube-system namespace to resolve the kubernetes service's fully qualified domain name.

**(Pause for emphasis)**  
If this had failed, it would mean our egress policy's DNS rules aren't working.  
But it succeeded because we explicitly allowed UDP and TCP port 53 to the kube-system namespace in our backend egress policy.  

**(Instructional tone)**  
This is the **most common mistake** people make with egress policies—they forget DNS, and then wonder why their pods can't resolve service names.

**(Instructional tone)**  
Let's also test DNS for services within our own namespace:

```bash
kubectl exec -n production-app backend -- getent hosts database
```

**(Voiceover)**  
You should see the database service's ClusterIP address returned.

**(Calm explanation)**  
Notice we're using just "database"—the short service name—not the fully qualified domain name.  
Kubernetes DNS automatically searches the pod's own namespace first.  
So "database" gets expanded to "database.production-app.svc.cluster.local" behind the scenes.

**(Pause)**  
This confirms DNS resolution is working for internal services within the namespace.  
Critical for service-to-service communication.

Note: Don't use curl or wget to test DNS alone—they'll attempt HTTP connections which may be blocked by egress policies even if DNS works. Use `getent hosts` to test pure DNS resolution.

**(Instructional tone, emphasis)**  
Now let's verify the backend CANNOT reach external destinations—let's try Google's DNS at 8.8.8.8:

```bash
kubectl exec -n production-app backend -- timeout 3 bash -c 'cat < /dev/null > /dev/tcp/8.8.8.8/53' && echo "Connection successful" || echo "Connection failed"
```

**(Voiceover)**  
After 3 seconds, you should see "Connection failed."

**(Pause with satisfaction)**  
Excellent. This proves our egress isolation is working.

**(Calm explanation)**  
Our backend egress policy has **two** specific allow rules:  
First—allow connections to pods labeled `tier=database` on port 5432.  
Second—allow connections to the kube-system namespace on ports 53 for DNS.

**(Pause)**  
Notice what's NOT in that list: external IP addresses.  
The backend pod cannot reach 8.8.8.8, cannot reach the internet, cannot reach anything outside those two specific allow rules.  
Egress traffic is locked down tight.

**(Instructional tone)**  
Let's also test that HTTP connections to external sites are blocked:

```bash
kubectl exec -n production-app backend -- curl --max-time 3 google.com
```

**(Voiceover)**  
This will timeout after 3 seconds.

**(Calm explanation)**  
Interesting thing here—curl will actually first try to resolve "google.com" via DNS.  
That DNS query succeeds because we allow DNS traffic to kube-system.  
So curl gets google.com's IP address.  

**(Pause)**  
But then when it tries to establish the HTTP connection on port 80 or 443, **that's** where the egress policy blocks it.  
The policy doesn't have any rule allowing connections to external IPs on HTTP ports.  
So even though DNS works, the actual connection is blocked.

**(Instructional tone)**  
This shows the difference between DNS resolution (which we allow) and actual connectivity (which we don't).

**(Instructional tone)**  
Now let's confirm the backend CAN connect to the database—the one egress path we explicitly allowed:

```bash
DATABASE_IP=$(kubectl get pod database -n production-app -o jsonpath='{.status.podIP}')
kubectl exec -n production-app backend -- timeout 3 bash -c "cat < /dev/null > /dev/tcp/$DATABASE_IP/5432" && echo "Connection successful" || echo "Connection failed"
```

**(Voiceover)**  
You should see "Connection successful."

**(Pause)**  
Perfect. This validates that our egress policy is working correctly—blocking what should be blocked, allowing what should be allowed.

**(Calm explanation)**  
We're using the database pod's IP address directly here to test raw connectivity.  
The backend pod's egress policy allows connections to pods with the label `tier=database` on TCP port 5432.  
The database pod has that label, so the connection is permitted.

**(Instructional tone)**  
This demonstrates precise egress control—we've locked down all outbound traffic except for the specific destinations and ports needed for the application to function.

### Test 2: Inspecting Policies

Sometimes you need to see which policies are selecting a pod:

**(Instructional tone)**  
Let's inspect the backend pod to see if there are any Network Policy-related issues:

```bash
kubectl describe pod backend -n production-app
```

**(Voiceover)**  
You'll see a lot of information about the pod—its status, containers, volumes, and so on.

**(Calm explanation)**  
Scroll down to the **Events** section at the bottom.  
This is where Kubernetes logs warnings or errors about the pod.  
If there were Network Policy conflicts or CNI issues, you'd see warnings here.

**(Pause)**  
In our case, you shouldn't see any Network Policy warnings because our policies are configured correctly.  
But if you had a typo in a selector, or if your CNI plugin wasn't working, you'd often find clues in the Events section.

**(Instructional tone)**  
Let's see all the Network Policies we've created in this namespace:

```bash
kubectl get networkpolicies -n production-app
```

**(Voiceover)**  
You should see a list of all our policies: default-deny-ingress, backend-allow-frontend, database-allow-backend, frontend-allow-egress, backend-allow-egress, and possibly others.

**(Calm explanation)**  
This gives you a quick overview of all active policies in the namespace.  
You can see their names and ages.  

**(Pause)**  
Remember—Network Policies are **namespaced** resources.  
These policies only affect pods in the production-app namespace.  
If you want to see policies in other namespaces, you'd need to specify a different namespace or use `--all-namespaces`.

**(Instructional tone)**  
Now let's get detailed information about a specific policy:

```bash
kubectl describe networkpolicy backend-allow-frontend -n production-app
```

**(Voiceover)**  
You'll see a formatted view of the policy with several key sections.

**(Calm explanation)**  
First, you'll see the **PodSelector** section showing `tier=backend`—this tells you which pods this policy applies to.  

**(Pause)**  
Then you'll see **Policy Types: Ingress**—meaning this policy controls incoming traffic.  

**(Pause)**  
Under **Ingress**, you'll see the allowed rules: pods matching `tier=frontend` can connect on TCP port 80.  

**(Instructional tone)**  
This describe command is **essential for debugging**.  
When a connection isn't working as expected, use this to verify your policy has the selectors and rules you think it has.  
Typos in label names, wrong ports, incorrect policy types—they'll all be visible here.

### Test 3: Validating Selectors

Common issue: selectors not matching intended pods. Test them before creating policies:

**(Instructional tone, emphasis)**  
Here's a pro tip—before you create a Network Policy, test your label selector to make sure it matches the pods you think it does:

```bash
kubectl get pods -n production-app -l tier=frontend
```

**(Voiceover)**  
You should see the frontend pod listed.

**(Calm explanation)**  
This command uses the `-l` flag for label selector—the same matching logic that Network Policies use.  
If your policy has `podSelector: matchLabels: tier=frontend`, then this command shows you exactly which pods will be affected.

**(Pause for emphasis)**  
If this returns no pods, or the wrong pods, your Network Policy selector won't work as intended.  
Always validate your selectors **before** creating policies.

**(Instructional tone)**  
This is especially helpful in the CKS exam—you can quickly verify your selector logic before applying the policy and potentially breaking connectivity.

**(Instructional tone)**  
To see all labels on a specific pod, use the `--show-labels` flag:

```bash
kubectl get pod backend -n production-app --show-labels
```

**(Voiceover)**  
You'll see the pod name, status, and then a LABELS column showing all labels like `tier=backend` and any others.

**(Calm explanation)**  
This is invaluable for troubleshooting selector mismatches.  
Maybe you think your pod has the label `tier=backend`, but it actually has `app=backend`.  
Or maybe there's a typo—`teir=backend` instead of `tier=backend`.

**(Pause)**  
These small mistakes break Network Policy selectors completely.  
The policy won't match the pod, and traffic won't be controlled as expected.

**(Instructional tone)**  
Use this command to verify the **exact** label keys and values, then ensure your policy's `matchLabels` uses identical spelling, case, and formatting.

### Troubleshooting Common Issues

**Problem 1: Policy has no effect.**

**(Instructional tone)**  
First, verify your CNI plugin supports Network Policies:

```bash
kubectl get pods -n kube-system
```

**(Voiceover)**  
You'll see all the control plane and system pods running in your cluster.

**(Calm explanation)**  
Look for pods with names like `calico-node`, `calico-kube-controllers`, or `cilium`, or `weave-net`.  
These are CNI plugins that support Network Policies.

**(Pause for emphasis)**  
If you don't see any of these, or if they're in a CrashLoopBackOff or Error state, then **Network Policies won't work**.  
The CNI is responsible for actually enforcing the policies by configuring iptables rules on each node.

**(Pause)**  
Note: The default CNI plugins like Flannel (in basic mode) do **not** support Network Policies.  
In our KIND cluster, we installed Calico specifically to get Network Policy support.

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

**(Instructional tone)**  
Network Policies are additive, so check for all policies that might be allowing the connection:

```bash
kubectl get networkpolicies -n production-app -o yaml
```

**(Voiceover)**  
This outputs the complete YAML for all Network Policies in the namespace.

**(Calm explanation)**  
You'll see every policy definition—all the selectors, all the ingress and egress rules, everything.  

**(Pause for emphasis)**  
Why is this important? Because Network Policies use **OR** logic.  
If **any** policy allows a connection, that connection is permitted—even if other policies don't explicitly allow it.

**(Pause)**  
So if you're seeing a connection that you think should be blocked, you need to review **all** policies.  
Maybe there's another policy with a broader selector that's allowing the traffic.  
Maybe someone created a policy you didn't know about.

**(Instructional tone)**  
Review the complete set of policies to understand the **union** of all allow rules—that's what determines actual connectivity.

**Problem 4: Selectors don't match.**

**(Instructional tone)**  
Verify the pod's labels match what you expect:

```bash
kubectl get pod <pod-name> -n production-app --show-labels
```

**(Calm explanation)**  
Replace `<pod-name>` with the actual pod name you're troubleshooting.

**(Pause)**  
The most common selector issues are:  
Typos in label keys—`tire` instead of `tier`.  
Wrong label values—`tier=front-end` when the policy says `tier=frontend`.  
Case sensitivity—`tier=Frontend` versus `tier=frontend`.  
Incorrect `matchExpressions` operators—using `In` when you meant `NotIn`.

**(Pause for emphasis)**  
Kubernetes label matching is **exact**.  
Even a single character difference means the selector won't match, and the policy won't apply to that pod.

### Advanced Testing

For thorough validation:

**(Instructional tone)**  
For thorough testing, create dedicated test pods with comprehensive network tools:

```bash
kubectl run test-client --image=nicolaka/netshoot -n production-app -- sleep 3600
```

**(Voiceover)**  
You'll see "pod/test-client created."

**(Calm explanation)**  
The netshoot image is a Swiss Army knife for network troubleshooting.  
It includes curl, nc (netcat), nslookup, dig, tcpdump, iftop, mtr, and dozens of other tools.  

**(Pause)**  
By having this pod running in your namespace, you can exec into it repeatedly to run different tests.  
You don't have to create a new pod for each test—just keep this one running and use it as your test client.

**(Instructional tone)**  
In the CKS exam, having a netshoot pod ready can save you precious time when you need to validate Network Policies quickly.

Note: The nginx containers used in our demos have limited tools (curl, wget, getent). For more comprehensive DNS testing with tools like nslookup or dig, use netshoot.

**(Instructional tone)**  
Also create a test pod in a different namespace to validate cross-namespace isolation:

```bash
kubectl run external-test --image=nicolaka/netshoot -n default -- sleep 3600
```

**(Voiceover)**  
This creates a test pod in the default namespace.

**(Pause)**  
Now let's try to connect from this external namespace:

```bash
kubectl exec -n default external-test -- curl backend.production-app.svc.cluster.local
```

**(Voiceover)**  
This should timeout and fail.

**(Calm explanation)**  
We're using the fully qualified service name to reach across namespaces.  
But even with the correct DNS name, the connection fails because our Network Policies only allow connections within the production-app namespace.

**(Pause)**  
If you wanted to allow cross-namespace connections, you'd need to add a `namespaceSelector` to your ingress rules.  
But we haven't done that, so namespace isolation is working correctly.

**(Instructional tone)**  
This validates that your policies are properly scoped to the namespace and not accidentally allowing external access.

### Best Practices

Five things for the CKS exam:

1. Test incrementally. One policy at a time. Don't create ten and hope.
2. Test positive AND negative cases. What should work and what should fail.
3. Always test DNS in egress policies. Most common failure.
4. Use descriptive names like `backend-allow-frontend`. Makes debugging easier.
5. Keep test pods ready. Netshoot in different namespaces saves time.

### Cleanup

**(Instructional tone)**  
When you're done with testing and want to clean up all resources:

```bash
kubectl delete namespace production-app
```

**(Voiceover)**  
You'll see "namespace 'production-app' deleted" after a few seconds.

**(Calm explanation)**  
Deleting the namespace removes everything inside it—all pods, services, and Network Policies.  
This is a quick way to clean up an entire test environment.

**(Pause)**  
Kubernetes will terminate all the pods, delete the services, and remove all Network Policy objects.  
The namespace itself will also be removed.

**(Instructional tone)**  
Be careful with this command in production—it's irreversible and deletes everything in the namespace.  
But for test environments and lab setups, it's a convenient cleanup method.

### Summary

Advanced testing is crucial for the CKS exam. You've learned to validate egress, inspect policies with `kubectl describe`, troubleshoot DNS failures and additive conflicts, validate selectors.

Key areas: verify CNI support, always allow DNS in egress, understand additive behavior, check label selectors carefully.

Master testing and troubleshooting, and you'll handle any Network Policy scenario in the exam or production.

---

**[End of Clip 3b]**
