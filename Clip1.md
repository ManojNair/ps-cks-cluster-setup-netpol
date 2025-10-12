# Clip 1: Introduction to Network Security Policies
**Duration:** ~5 minutes

---

## Voiceover Script

Alright, let's talk about network security policies in Kubernetes. If you're studying for the CKS exam, this topic comes up a lot, and for good reason. We're going to cover what network policies actually do, why they matter for security, and the core concepts you need to understand.

### What Are Network Policies?

Think about a typical Kubernetes cluster for a moment. You've got pods running everywhere—frontend, backend, database, maybe some microservices. By default, Kubernetes networking is wide open. Any pod can connect to any other pod. Which is convenient for development, sure, but from a security standpoint? Not great.

Network Policies are basically firewall rules at the pod level. They work at layer 3 and 4—IP addresses and ports. You can define rules like "frontend can talk to backend on port 80, but only backend can reach the database on 5432." That kind of thing.

### Why This Matters for CKS

For the exam, you'll need hands-on experience with these. Not just theory—you'll create policies, troubleshoot them, maybe fix broken ones. In production, network policies give you that least privilege principle for network traffic. If someone compromises a pod, they can't just bounce around your entire cluster freely.

### The CNI Plugin Requirement

Here's something critical though. Network Policies only work if your CNI plugin supports them. CNI is your Container Network Interface—handles all the networking in your cluster.

And not all CNI plugins support Network Policies. You could write a perfect policy, apply it, and... nothing happens. The resource gets created in etcd, but it has zero effect. The most common ones that DO work are Calico, Cilium, and Weave Net. For practicing, I'd go with Calico—it's what you'll see most often in production.

### Understanding Pod Isolation

Let's break down how isolation actually works, because this trips people up.

There are two directions to think about: ingress and egress. Ingress is incoming traffic—who can connect TO your pod. Egress is outgoing—where your pod can connect TO.

By default, pods aren't isolated at all. They can receive from anywhere, connect to anywhere. When you apply a Network Policy that selects a pod, that pod becomes isolated for whatever you specify—ingress, egress, or both.

Now here's where it gets interesting. Network Policies are additive. Multiple policies selecting the same pod? The allowed traffic is the union of all those rules. They stack, they don't conflict.

And for a connection between two pods to actually work, both sides have to agree. The source's egress policy AND the destination's ingress policy both need to allow it. Either side can block the connection.

### The Basic Structure

Let me give you a quick overview of what these policies look like. Standard Kubernetes resource—you've got apiVersion, kind, metadata. The spec is where things get interesting.

You've got `podSelector`—this picks which pods the policy applies to using labels, just like deployments. Empty podSelector means all pods in the namespace.

Then `policyTypes`—Ingress, Egress, or both. Pretty straightforward.

Ingress rules define who can connect to your pods. You can use pod selectors, namespace selectors, IP blocks. Plus which ports and protocols.

Egress rules are the opposite direction—where your pods can connect TO.

### Namespace Scoping

One more thing. Network Policies are namespaced. A policy in namespace A protects pods in namespace A. It can reference other namespaces in its rules, but it lives in and protects its own namespace. Matters a lot for multi-tenant setups.

### Summary

So that's the foundation. Network Policies let you control pod-to-pod communication at the network layer. They're namespace-scoped, they're additive, and they need a compatible CNI plugin to actually do anything.

For the CKS exam, you need to be comfortable with these concepts and ready to work with them hands-on.

---

**[End of Clip 1]**
