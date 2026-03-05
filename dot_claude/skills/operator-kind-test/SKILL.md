---
name: operator-kind-test
user_invocable: true
description: "Build and deploy the Datadog Operator from local source into a kind (Kubernetes in Docker) cluster for testing. Use this skill whenever the user wants to test operator changes locally, deploy the operator to a local cluster, verify operator behavior on Kubernetes, or iterate on operator code with a real cluster. Invoke this whenever someone mentions testing the operator locally, deploying to kind, or any task involving a local Kubernetes environment + Datadog Operator — even if they don't explicitly say 'kind' or 'operator-kind-test'."
hint: "/operator-kind-test - Build and deploy the Datadog Operator to a local kind cluster"
---

You are helping deploy and test the Datadog Operator from local source on a kind cluster. This gives you a real Kubernetes environment to verify operator changes against the Datadog backend.

The whole flow runs locally: create a kind cluster, build the operator image, load it into kind, deploy, and apply a DatadogAgent CR so the agent connects to Datadog.

## Step 0: Clean up any existing kind cluster

A previous test cluster may still be running. Delete it first so you start clean — this is idempotent and safe even if no cluster exists:

```bash
# Delete any existing DatadogAgent CR first (avoids finalizer hang)
kubectl --context kind-datadog-operator-test -n system delete datadogagent datadog --ignore-not-found 2>/dev/null || true

# Delete the kind cluster
kind delete cluster --name datadog-operator-test 2>/dev/null || true
```

## Step 1: Gather parameters

Extract from the user's request:
- **environment**: default to **production** (`app.datadoghq.com`) unless the user says "staging" — then use `dd.datad0g.com`.
- **operator source path**: the root of the datadog-operator repo checkout. Default to the current working directory if it looks like the operator repo (contains `cmd/main.go` and `api/datadoghq/`).

## Step 2: Create the kind cluster

```bash
kind create cluster --name datadog-operator-test
```

This creates a single-node cluster and sets `kubectl` context to `kind-datadog-operator-test`.

## Step 3: Build the operator Docker image

The Datadog internal Go proxy (`depot-read-api-go.us1.ddbuild.io`) is often unreachable from local machines. Override `GOPROXY` to use the public proxy:

```bash
GOPROXY=https://proxy.golang.org,direct make docker-build IMG=datadog-operator:local
```

This builds the operator binary inside Docker using the repo's Dockerfile and tags it as `datadog-operator:local`.

## Step 4: Load the image into kind

Kind clusters can't pull from the local Docker daemon directly. Load the image explicitly:

```bash
kind load docker-image datadog-operator:local --name datadog-operator-test
```

## Step 5: Install CRDs and deploy the operator

```bash
GOPROXY=https://proxy.golang.org,direct make install
GOPROXY=https://proxy.golang.org,direct make deploy IMG=datadog-operator:local
```

This installs all CRDs (DatadogAgent, DatadogMonitor, etc.) and deploys the operator into the `system` namespace.

After deploying, verify the operator pod is running:

```bash
kubectl -n system get pods
```

Wait until the operator pod shows `Running` and `1/1` ready.

## Step 6: Obtain the API key (local)

Run the following to get a Datadog API key:

```bash
# Production
dd-auth -s app.datadoghq.com -o

# Staging
dd-auth -s dd.datad0g.com -o
```

Capture the API key from the output.

## Step 7: Create the API key secret

```bash
kubectl -n system create secret generic datadog-secret \
  --from-literal api-key=<API_KEY>
```

Replace `<API_KEY>` with the key obtained in the previous step.

## Step 8: Deploy a minimal DatadogAgent CR

Apply this manifest to get the agent running with minimal config.

For **staging**, set `spec.global.site` to `datad0g.com` so the agent reports to the staging backend. For **production**, either omit the `site` field (defaults to `datadoghq.com`) or set it explicitly.

```yaml
apiVersion: datadoghq.com/v2alpha1
kind: DatadogAgent
metadata:
  name: datadog
  namespace: system
spec:
  global:
    clusterName: kind-operator-test
    site: datad0g.com  # staging — omit or use "datadoghq.com" for production
    credentials:
      apiSecret:
        secretName: datadog-secret
        keyName: api-key
    kubelet:
      tlsVerify: false
```

- `site` controls which Datadog intake the agent sends data to. It must match the environment used in `dd-auth`.
- `tlsVerify: false` is needed because kind uses self-signed kubelet certificates.

If the user has a custom DatadogAgent manifest they want to test, use that instead — just make sure:
- The namespace is `system`
- The credentials reference the `datadog-secret` secret
- `kubelet.tlsVerify` is `false`
- `site` matches the environment used to obtain the API key

## Step 9: Verify everything is running

```bash
# Wait for agent pods
kubectl -n system wait --for=condition=ready pod -l app.kubernetes.io/name=datadog-agent-deployment --timeout=120s

# Show all pods
kubectl -n system get pods

# Check operator logs for errors
kubectl -n system logs deployment/datadog-operator-manager --tail=30

# Check DatadogAgent status conditions
kubectl -n system get datadogagent datadog -o jsonpath='{range .status.conditions[*]}{.type}{": "}{.status}{"\n"}{end}'
```

You should see:
- `datadog-operator-manager` — 1/1 Running
- `datadog-cluster-agent-*` — 1/1 Running
- `datadog-agent-*` — 2/2 Running (agent + process-agent containers)

## Step 10: Hand off to the user

Summarize what's running and provide useful commands:

```
Kind cluster is ready: datadog-operator-test

Useful commands:
  # Operator logs
  kubectl -n system logs deployment/datadog-operator-manager -f

  # Agent status
  kubectl -n system get pods

  # DatadogAgent status
  kubectl -n system get datadogagent datadog -o yaml

  # Rebuild and redeploy after code changes
  GOPROXY=https://proxy.golang.org,direct make docker-build IMG=datadog-operator:local
  kind load docker-image datadog-operator:local --name datadog-operator-test
  kubectl -n system rollout restart deployment/datadog-operator-manager

  # Cleanup
  kubectl -n system delete datadogagent datadog
  kind delete cluster --name datadog-operator-test
```

Remind the user to always delete the DatadogAgent CR before removing the cluster — the finalizer will block deletion otherwise.
