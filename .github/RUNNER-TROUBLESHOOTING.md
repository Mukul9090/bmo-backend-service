# Runner Connection Troubleshooting

## Issue: Jobs Queuing Instead of Running

If your runner shows "listening for jobs" but jobs are stuck in queue, check the following:

### 1. Verify Runner Labels

The workflow uses these labels:
```yaml
runs-on:
  - self-hosted
  - macOS
  - ARM64
```

**Check your runner labels:**
- Go to: GitHub → Settings → Actions → Runners
- Click on your runner "BMO-platform"
- Verify it has these labels: `self-hosted`, `macOS`, `ARM64`

**If labels don't match:**
- Option A: Update runner labels to match workflow
- Option B: Update workflow to match runner labels

### 2. Alternative: Use Runner Name Directly

If labels don't work, you can use the runner name directly:

```yaml
runs-on: BMO-platform
```

But this only works if:
- Runner name exactly matches (case-sensitive)
- Runner is registered at repository level (not organization level)

### 3. Check Runner Registration Level

**Repository-level runner:**
- Registered for specific repository
- Workflow can use runner name directly: `runs-on: BMO-platform`

**Organization-level runner:**
- Registered for entire organization
- Must use labels: `runs-on: [self-hosted, macOS, ARM64]`

### 4. Verify Runner Status

On the runner machine, check:
```bash
# Check if runner service is running
# macOS: Check Activity Monitor or:
ps aux | grep Runner.Listener

# Check runner logs
# Logs location: ~/actions-runner/_diag/
```

### 5. Restart Runner

If runner is stuck:
```bash
# Stop runner
./run.sh stop

# Start runner again
./run.sh
```

### 6. Re-register Runner (Last Resort)

If nothing works:
1. Remove runner from GitHub (Settings → Actions → Runners → Remove)
2. Re-register with correct labels:
   ```bash
   ./config.sh --url https://github.com/Mukul9090/bmo-backend-service --token <TOKEN> --labels "self-hosted,macOS,ARM64"
   ```

## Current Workflow Configuration

The workflow now uses labels (recommended approach):
```yaml
runs-on:
  - self-hosted
  - macOS
  - ARM64
```

This matches the standard self-hosted runner labels and should work if your runner was registered with these labels.

## Quick Fix Commands

```bash
# On runner machine - check labels
cat ~/actions-runner/.runner | grep labels

# Restart runner
cd ~/actions-runner
./run.sh stop
./run.sh
```

