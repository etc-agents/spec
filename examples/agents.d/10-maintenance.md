## Maintenance in progress

Example of a runtime fragment. A deploy or maintenance script writes it to
`/run/agents.d/10-maintenance.md` and removes it at the end. `/run` is
empty after a reboot, so a forgotten fragment does not stay for ever.

Kernel upgrade started 13:40 UTC by Ansible (change CHG-1234). A reboot is
expected before 14:30 UTC. Do not start long-running jobs. Alerts for this
host in this window are expected; do not act on them.
