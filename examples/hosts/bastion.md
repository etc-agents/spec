# bastion-1.example.net

## Role
SSH bastion. The only entry point from the internet to the production
network. It runs nothing except sshd and the audit shipper.

If this host is unreachable, nobody can reach production, including the
people who would fix this host. Treat each change here as high risk.

## Owner
Team security. Contact: #security-oncall.

## Where things are
- sshd config: /etc/ssh/sshd_config.d/ (managed by Ansible, role `bastion`)
- Auth log: `journalctl -u ssh`
- Session audit: shipped to the SIEM by `auditbeat`. Local copies in
  /var/log/audit are kept for 7 days.

## Safe operations
- Read logs. Read configuration.
- `sshd -t` to validate configuration.

## Do not
- Do not restart or reload sshd without a second open session and a
  successful `sshd -t`. A bad config locks everybody out.
- Do not edit authorized_keys files. Keys come from the identity provider
  through `AuthorizedKeysCommand`.
- Do not change firewall rules. They are managed in the network repository
  and a manual rule is removed within 30 minutes.
- Do not stop auditbeat or auditd, also not to reduce load. A gap in the
  audit trail is a compliance incident.
- Do not install packages. The host has a fixed package set.

## Escalation
Any sign of unauthorised access (unknown key, unknown source address,
unexpected process): stop, change nothing, page security. Evidence matters
more than a quick fix.

Last reviewed: 2026-11-12
