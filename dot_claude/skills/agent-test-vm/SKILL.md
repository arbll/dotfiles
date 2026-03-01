---
name: agent-test-vm
user_invocable: true
description: "Set up a GCP VM with the Datadog agent installed for testing. Use this skill whenever the user wants to test the Datadog agent, spin up a test VM, reproduce a customer issue, verify agent behavior, or run agent integration tests on a fresh machine. Invoke this whenever someone mentions testing the agent on a VM, installing the agent on a cloud instance, or any task involving a fresh Linux environment + Datadog agent setup — even if they don't explicitly say 'agent-test-vm'."
hint: "/agent-test-vm - Create a GCP VM with Datadog agent installed for testing"
---

You are helping set up a Datadog agent test environment on GCP. Work through the steps below, paying close attention to which commands run **locally** (on the user's machine) vs. **remotely** (on the VM via SSH).

## Step 1: Gather parameters

Extract from the user's request:
- **test-goal**: a short kebab-case label for what's being tested (e.g., `log-collection`, `apm-tracing`, `process-monitoring`). If the user just wants a VM with the agent and no specific test, use a descriptive label like `agent-setup`.
- **environment**: default to **production** (`app.datadoghq.com`) unless the user says "staging" — in that case use `dd.datad0g.com`.

VM name will be: `arbll-claude-<test-goal>`

## Step 2: Create the VM (local)

The `datadog-sandbox` project uses custom-subnet VPCs, so you must specify both `--zone` and `--subnet`. Use `us-central1-a` and the `default` subnet (on the `default` network) as defaults:

```bash
gcloud compute instances create arbll-claude-<test-goal> \
  --project=datadog-sandbox \
  --zone=us-central1-a \
  --machine-type=c2-standard-8 \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --scopes=cloud-platform \
  --subnet=default
```

Wait for the instance to be created. Note the external IP from the output — you'll need it to confirm SSH access.

## Step 2.5: Ensure SSH firewall rule exists (local)

The `default` network in `datadog-sandbox` has no SSH rule by default. Check if one already exists for your IP, and create it if not:

```bash
gcloud compute firewall-rules list \
  --project=datadog-sandbox \
  --filter="network:default AND allowed[].ports[]:22" \
  --format="table(name,sourceRanges)"
```

If no rule covers your IP, create one (replace `<YOUR_IP>` with your actual public IP):

```bash
gcloud compute firewall-rules create arbll-allow-ssh \
  --project=datadog-sandbox \
  --network=default \
  --allow=tcp:22 \
  --source-ranges=<YOUR_IP>/32 \
  --description="Allow SSH from arbll IP"
```

This rule is reusable across sessions — you only need to create it once.

## Step 3: Obtain the API key (local — NEVER run this on the VM)

Run the following **on your local machine**:

```bash
# Production
dd-auth -s app.datadoghq.com -o

# Staging
dd-auth -s dd.datad0g.com -o
```

Capture the API key from the output. Also set the `DD_SITE` based on environment:
- Production: `datadoghq.com`
- Staging: `datad0g.com`

## Step 4: Install the Datadog agent (on the VM)

Download the install script to a temp file first, then run it. This avoids shell quoting issues that occur when embedding `$(curl ...)` in `--command`:

```bash
gcloud compute ssh arbll-claude-<test-goal> \
  --project=datadog-sandbox \
  --zone=us-central1-a \
  --command='curl -fsSL https://install.datadoghq.com/scripts/install_script_agent7.sh -o /tmp/install.sh && sudo DD_API_KEY="<API_KEY>" DD_SITE="<DD_SITE>" bash /tmp/install.sh'
```

Once installation completes, verify the agent is running:

```bash
gcloud compute ssh arbll-claude-<test-goal> \
  --project=datadog-sandbox \
  --zone=<zone> \
  --command='sudo datadog-agent status'
```

## Step 5: Run the test (if the user requested one)

If there is a specific test to perform:
- Consult the [Datadog documentation](https://docs.datadoghq.com) as needed to understand how to configure and test the feature.
- Think from the customer's perspective: configure the agent, generate test data, and verify it appears correctly.
- Run test steps on the VM using `gcloud compute ssh ... --command='...'`. For multi-step workflows, chain commands or pipe a heredoc.

Useful reference for tests:
- Agent config: `/etc/datadog-agent/datadog.yaml`
- Config directory: `/etc/datadog-agent/conf.d/`
- Agent commands: `sudo datadog-agent start|stop|restart|status`
- Agent logs: `/var/log/datadog/agent.log`
- Verify specific integrations: `sudo datadog-agent check <integration-name>`

## Step 6: Hand off to the user

Leave the VM running as-is. Summarize what was set up (and what the test showed, if one was run), then provide the SSH command for manual debugging:

```
VM is ready: arbll-claude-<test-goal> (zone: <zone>)

To connect:
  gcloud compute ssh arbll-claude-<test-goal> --project=datadog-sandbox --zone=<zone>
```
