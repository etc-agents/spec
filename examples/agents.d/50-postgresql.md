## PostgreSQL (package fragment)

Example of a fragment that a distribution package could install as
`/usr/lib/agents.d/50-postgresql.md`. It contains only facts that are true
on every host with this package.

- Clusters: `pg_lsclusters` lists version, name, port and data directory.
- Service units: `postgresql@<version>-<cluster>.service`. The plain
  `postgresql.service` is an umbrella unit; its status says little.
- Logs: `journalctl -u postgresql@<version>-<cluster>`.
- Config: /etc/postgresql/<version>/<cluster>/.
- Most settings need only a reload: `systemctl reload postgresql@...`.
  `SELECT name FROM pg_settings WHERE pending_restart;` shows the settings
  that wait for a restart.
- Never delete files in `pg_wal` or `pg_xact` by hand, also not when the
  disk is full. The cluster does not start again.
- Never use `kill -9` on a backend process. The postmaster then restarts
  all backends. Use `SELECT pg_terminate_backend(pid);`.
