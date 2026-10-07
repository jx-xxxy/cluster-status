# Cluster Status

This small dashboard publishes only the current user's Slurm jobs.

The public page never collects other users' jobs. The updater runs on the cluster and pushes only `index.html` when the queue state changes.

## Update once

```bash
chmod +x update_status.sh
./update_status.sh .
```

## Refresh every five minutes

```cron
*/5 * * * * /bin/bash /home/jiangxin/cluster-status/sync_status.sh /home/jiangxin/cluster-status >/dev/null 2>&1
```

The public page contains job name, state, elapsed time, and node/reason for the current user only. It does not collect other users' jobs, passwords, tokens, or calculation files.

