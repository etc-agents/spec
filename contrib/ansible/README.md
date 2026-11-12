# Ansible role: etc_agents

Writes `/etc/agents` and `/etc/agents.d/*.md` with the ownership and modes
that the specification requires (root, `0644`, directory `0755`).

```yaml
- hosts: db_replicas
  become: true
  roles:
    - role: etc_agents
      vars:
        etc_agents_role: >-
          PostgreSQL 17 streaming replica for billing. Production.
          The primary is db-primary-1.
        etc_agents_owner: "Team data-platform. On-call: #data-oncall."
        etc_agents_locations:
          - "Logs: `journalctl -u postgresql@17-main`"
          - "Data: /var/lib/postgresql/17/main"
        etc_agents_do_not:
          - "Do not run `pg_ctl promote`. Promotion needs the failover runbook."
        etc_agents_escalation: "Replication lag above 10 minutes: page the on-call."
        etc_agents_reviewed: "2026-11-12"
        etc_agents_fragments:
          90-site: |
            ## Site rules
            Change freeze from 20 December to 5 January.
```

To supply the whole file yourself, set `etc_agents_content` to the Markdown
text. See [defaults/main.yml](roles/etc_agents/defaults/main.yml) for all
variables.

Group variables work well: put the facts that are true for a whole group
(`etc_agents_owner`, common `etc_agents_do_not` items) in `group_vars`, and
the host-specific role in `host_vars`.
