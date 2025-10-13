# 🎙️ Clip 2: Creating Network Policies – Ingress Rules (Narration Script v4)

---

## Opening Context – The Lab Environment  

**(Tone: friendly and conversational)**  
Before we dive in — let me quickly talk about the environment I'll be using for all the demos in this course... **KIND running in GitHub Codespaces**.

**(Pause)**  
GitHub Codespaces gives us a fantastic cloud-based development environment with **VS Code** in the browser —   
and the best part?  
We can spin up a full **KIND** cluster with **Calico networking** that supports Network Policies right out of the box.

**(Slight emphasis)**  
Now, you might be wondering — *why this setup?*  

Codespaces helps you **provision a Kubernetes cluster quickly** so you can focus on learning the core concepts required for the exam — without getting bogged down in cluster setup details.

But here's the thing — once you've got a solid handle on these concepts, I'd strongly recommend practicing on **Killerkoda** or the **Killer Shell** platforms that you get access to as part of your certification purchase.

**(Pause)**  
Those platforms will help you get familiar with the actual **exam environment** — the remote desktop feel, the performance characteristics, and the exact tooling you'll have during the real test.

So think of it this way: **Codespaces for learning**, **Killer Shell for exam prep**.

Now, let's quickly set up our environment to match the exam experience.  
We'll configure the **`k`** alias for `kubectl` and enable bash autocompletion — both are *huge* time-savers during the exam.

```bash
alias k=kubectl
echo 'alias k=kubectl' >> ~/.bashrc
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
```

**(Pause)**  
Perfect! Now we can use **`k`** just like in the real exam, and tab completion will work seamlessly.  

And since we're in a browser, we can easily switch between our terminal and the **kubernetes.io** documentation when we need to look up YAML snippets.  
Later in this course, I'll show you some quick **navigation and time-saving tips** that make a real difference in your score.

If you want to follow along, you can use the same setup — **GitHub Codespaces with KIND** —   
or your own local cluster like **Docker Desktop**, **Minikube**, or any other Kubernetes setup.  

Personally, I love this Codespaces approach because it's consistent, reproducible, and gives us that cloud-native feel while still having access to proper tooling.

**(Pause, transition)**  
Now before we begin writing our policies — one quick note.  
In this clip, we’ll be **crafting** our Network Policies, but we won’t actually test them yet.  
Right now, I want you to focus entirely on the **syntax** and the **core concepts**.  
We’ll test and validate these policies in a later clip once we’ve built a solid foundation.

**(Pause for transition)**  
Alright — with that out of the way, let’s get hands-on with **Network Policies**.

---

## Creating Network Policies – Ingress Rules

Let’s roll up our sleeves and actually create some Network Policies.  
We’ll walk through a few real-world examples — and I’ll explain each YAML file, line by line, so it all clicks.

---

### Demo Setup  

We'll start with a simple **three-tier app** — frontend, backend, and database.  

Since we're using our **KIND cluster with Calico**, we already have Network Policy support built in — so we're ready to go!

**(Instructional tone)**  
Let’s open our terminal and create a new namespace called *production-app*:  

```bash
kubectl create namespace production-app
```

**(Voiceover)**  
Once that's done, let's spin up three pods — one for each tier of the application.  

```bash
kubectl run frontend --image=nginx --labels=tier=frontend -n production-app
kubectl run backend --image=nginx --labels=tier=backend -n production-app
kubectl run database --image=postgres:13 --labels=tier=database -n production-app --env="POSTGRES_DB=myapp" --env="POSTGRES_USER=appuser" --env="POSTGRES_PASSWORD=securepass123"
```

**(Calm pacing)**  
This creates two NGINX pods for frontend and backend, and a PostgreSQL database pod with proper credentials.

Now let's expose these pods as services so they can communicate properly:

```bash
kubectl expose pod frontend --port=80 --target-port=80 -n production-app
kubectl expose pod backend --port=80 --target-port=80 -n production-app
kubectl expose pod database --port=5432 --target-port=5432 -n production-app
```

**(Pause)**  
This creates services for each pod — frontend and backend on port 80, and database on PostgreSQL's standard port 5432.
The services will have the same labels as the pods, so network policies will work correctly.
Right now, all of them can freely talk to each other.  

**(Pause)**  
That’s... not great for security. Let’s lock that down.

---

### Example 1: Default Deny Ingress Policy  

Let’s start with our **first policy** — a *default deny ingress* policy.  
And this time, instead of memorizing YAML, we’ll do it the *exam way* — using the **official Kubernetes documentation**.

**(Instructional tone)**  
Let's open a new browser tab in our Codespaces environment and go to **kubernetes.io**.  
In the search bar, type **"netpol."**

**(Pause)**  
On the right-hand side, under **Default policies**, you’ll see an example titled *Default deny all ingress traffic*.  
Click it, and copy the sample YAML from that page.

**(Encouraging tone)**  
This is an important habit to build for the exam — rather than trying to memorize,  
know **where** to find snippets and how to adapt them quickly.  

Now, back in your terminal, let's paste that into a file called `default-deny-ingress.yaml`.  
It should look like this:

```bash
cat << EOF > default-deny-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

Let’s break this down.

- `apiVersion` — `networking.k8s.io/v1` is stable since Kubernetes 1.7.  
- `metadata` — defines name and namespace; remember, **Network Policies are namespaced**.  
- `podSelector: {}` — those empty braces mean “apply to *all* pods in this namespace.”  
- And `policyTypes: - Ingress` — we’re targeting incoming traffic.

Now — notice there are no `ingress` rules here.  
**No rules means no traffic allowed.** That’s our **default deny**.

**(Voiceover)**  
Let’s go ahead and apply this policy:  

```bash
kubectl apply -f default-deny-ingress.yaml
```

You should see output saying “networkpolicy/default-deny-ingress created.”  
That means all pods are now isolated for ingress — nothing can connect *in*.  
Egress is still open, which is fine for now.

---

### Example 2: Allow Frontend to Backend  

Next, let’s allow a specific communication path — frontend to backend on port 80.  

**(Voiceover)**  
Create a new file called `backend-allow-frontend.yaml` and paste this in:  

```bash
cat << EOF > backend-allow-frontend.yaml
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
EOF
```

**(Calm explanation)**  
Here’s what’s happening:  

- `podSelector` targets pods labeled `tier=backend`.  
- Under `ingress: from:`, we allow traffic only from pods labeled `tier=frontend`.  
- Since there’s no `namespaceSelector`, this applies just within the same namespace.  
- And finally, port 80 for TCP traffic is explicitly allowed.  

**(Voiceover)**  
Let’s apply it:  

```bash
kubectl apply -f backend-allow-frontend.yaml
```

You should see confirmation that the policy was created.  
Now only the frontend can talk to the backend on port 80 — and nothing else.

---

### Example 3: Allow Backend to Database  

Now we'll connect the backend to the database — port 5432 for PostgreSQL.

**(Voiceover)**  
Create a file named `database-allow-backend.yaml` and add:  

```bash
cat << EOF > database-allow-backend.yaml
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
      port: 5432
EOF
```

Same structure, but this time for the database layer.

**(Voiceover)**  
Let’s apply this one too:  

```bash
kubectl apply -f database-allow-backend.yaml
```

Now we have a clear, layered policy chain:  
Frontend → Backend (80)  
Backend → Database (5432)  
Everything else is blocked.

---

### Summary  

Let’s recap what we learned.  

We started by copying a **default deny ingress** policy directly from **kubernetes.io**,  
then gradually opened up specific paths.  
This reflects the **least privilege** model in Kubernetes.  

Key takeaways:  
- `podSelector` defines which pods the policy targets.  
- `policyTypes` tells Kubernetes if it’s controlling ingress, egress, or both.  
- And `ingress` rules specify **who** can connect and **on which ports**.  

That **deny-by-default** mindset is essential — both for **real-world clusters** and for the **CKS exam**.  
And remember — you don’t have to memorize YAML.  
Just know how to find and adapt it quickly on **kubernetes.io**.

**(Pause, confident close)**  
Nice work — let’s move on.

---

**[End of Clip 2]**
