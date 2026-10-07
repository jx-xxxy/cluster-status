# Cluster Status

This small dashboard publishes only the current user's Slurm jobs.

## Update once

```bash
chmod +x update_status.sh
./update_status.sh .
```

## Refresh every five minutes

```cron
*/5 * * * * /home/jiangxin/cluster-status/update_status.sh /home/jiangxin/cluster-status >/dev/null 2>&1
```

The public page contains job name, state, elapsed time, and node/reason for the current user only. It does not collect other users' jobs, passwords, tokens, or calculation files.

