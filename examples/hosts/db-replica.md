# db-replica-2.prod.example.net

## Role
PostgreSQL 17 streaming replica for the billing cluster. Production.
Read-only traffic from the reporting service arrives through pgbouncer on
port 6432. The primary is db-primary-1.

## Owner
Team data-platform. On-call: #data-oncall.

## Where things are
- Data: /var/lib/postgresql/17/main (do not write here)
- Logs: `journalctl -u postgresql@17-main`
- Config: managed by Ansible, role `postgres`. Local edits are overwritten.

## Safe operations
- Any SELECT through `psql -U monitor`.
- `systemctl status`, `journalctl`, `pg_lsclusters`.

## Do not
- Do not restart postgresql between 06:00 and 08:00 UTC. The nightly
  reports run then, and a restart makes them fail without an alert.
- Do not run `pg_ctl promote`. A promotion needs the failover runbook and
  a human.
- Do not free disk space by deleting files in pg_wal.

## Escalation
Replication lag above 10 minutes: stop and page the on-call.

Last reviewed: 2026-11-12
