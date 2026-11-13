# /etc/agents

**A host-level instruction file for AI agents. `motd`, but for agents.**

| | |
|---|---|
| Version | 0.1 (draft) |
| Date | 2026-11-12 |
| Author | Andrey Gerasimov |
| Status | Draft for comment. Anything can change before 1.0. |

## 1. Summary

`/etc/agents` is a Markdown file that tells an AI agent what a Linux host is
and how to work on it safely. Any agent can read it, whether the agent runs
on the host or reaches it over SSH. The file needs no tooling:

```sh
cat /etc/agents
```

Packages and configuration management add fragments in `/etc/agents.d/`.

## 2. Motivation

Agents now operate servers: they investigate incidents, patch packages and
restart services. An agent that lands on a host starts with nothing. It does
not know that the host is a production database replica, that the
application logs are in `/srv/app/log`, or that a restart of `haproxy` drops
live calls. It discovers these facts by trial, or it does not discover them.

Humans solved this for themselves long ago with `/etc/motd`, wiki pages and
tribal knowledge. Repositories solved it for coding agents with
[AGENTS.md](https://agents.md/). Hosts have no equivalent. Some agents read a
vendor-specific file (`/etc/ampcode/AGENTS.md`, `/etc/claude-code/CLAUDE.md`),
but those files carry the policy of one vendor's tool, not a description of
the machine.

`/etc/agents` fills that gap: one vendor-neutral place, on the host itself,
owned by the people who run the host.

## 3. Goals and non-goals

Goals:

- One predictable location that every agent can check.
- Readable with `cat`. Writable with any editor, Ansible or a package.
- Follows existing `/etc` conventions, so an administrator can guess how it
  works.
- Safe by default against the obvious attack: a host file is a
  prompt-injection target.

Non-goals:

- **Not an enforcement mechanism.** The file informs. Permissions, sudo
  rules, credentials and sandboxes enforce.
- **Not a secret store.**
- **Not a configuration format for a specific agent product.**
- **Not a replacement for AGENTS.md.** That file describes a repository.
  This file describes a machine.

## 4. Terminology

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be read as
described in RFC 2119.

- **Host**: one Linux system: a physical server, a virtual machine or a
  container.
- **Agent**: software that uses a language model to decide which commands to
  run on a host.
- **Principal**: the person or system on whose behalf the agent acts, and
  whose instructions the agent already has.
- **Host document**: the text that results from the load procedure in
  section 6.
- **Fragment**: one `*.md` file in a drop-in directory.

## 5. Files

### 5.1 Main file

```
/etc/agents
```

A regular file with Markdown content. It has no extension, in the same way
that `/etc/motd` and `/etc/hosts` have none. The local administrator owns it.

### 5.2 Drop-in directories

| Directory | Written by | Typical content |
|---|---|---|
| `/etc/agents.d/` | Administrator, configuration management | Site-specific facts and rules |
| `/run/agents.d/` | Services and scripts, at runtime | Temporary state: "maintenance until 14:00 UTC" |
| `/usr/lib/agents.d/` | Distribution packages | How a packaged service is laid out and operated |

Rules for fragments:

- A fragment file name MUST end in `.md` and MUST contain only the characters
  `A-Z a-z 0-9 _ . -`. An agent MUST ignore other files.
- A two-digit prefix is RECOMMENDED to control order: `50-postgresql.md`.
- When the same file name exists in more than one directory, only one file
  is used. `/etc/agents.d/` wins over `/run/agents.d/`, which wins over
  `/usr/lib/agents.d/`. This is the precedence that systemd uses for its own
  drop-ins.
- To disable a fragment that a package ships, the administrator creates an
  empty file, or a symbolic link to `/dev/null`, with the same name in
  `/etc/agents.d/`.

All files and directories are optional. A host with only `/etc/agents`
conforms. A host with only fragments conforms.

### 5.3 Ownership and permissions

- Each file and each drop-in directory MUST be owned by root (uid 0) and
  MUST NOT be writable by group or others.
- Mode `0644` for files and `0755` for directories is RECOMMENDED. A stricter
  mode is permitted when the host description is itself sensitive. An agent
  that cannot read a file treats it as absent.

## 6. Loading

### 6.1 Procedure

An agent builds the host document as follows:

1. If `/etc/agents` exists and passes the trust check (6.2), take its
   content.
2. Collect the set of fragment file names from the three drop-in
   directories.
3. Sort the names in byte order (`LC_ALL=C`).
4. For each name, select the file from the highest-priority directory that
   contains it. If that file passes the trust check and is not empty, append
   a blank line and its content.

There is no include directive. An agent MUST NOT fetch a URL or read another
file merely because the host document refers to it.

### 6.2 Trust check

An agent MUST skip a file when, after symbolic links are resolved:

- the file is not owned by uid 0, or
- the file is writable by group or others, or
- the directory that contains a fragment fails either test.

A skipped file still masks files of the same name in lower-priority
directories. An agent SHOULD report a skipped file to its principal, because
a writable file in this location is a sign of misconfiguration or tampering.

### 6.3 When to read

- An agent SHOULD load the host document once, before its first
  state-changing action on a host, and MAY load it before any command.
- An agent that works on several hosts MUST keep each host document attached
  to its own host. Text from host A is not context for host B.
- An agent MAY cache the document for the length of one task. It SHOULD NOT
  reuse a cached copy for a later task, because `/run/agents.d/` changes.
- When no file exists, there is no host document. This is not an error and
  an agent SHOULD NOT mention it.

### 6.4 Size

The host document SHOULD stay below 32 KiB. An agent MAY truncate a larger
document. If it does, it MUST keep the start of the document and SHOULD tell
its principal that it truncated the text.

### 6.5 Reference loader

This POSIX shell script implements 6.1 and 6.2. It works locally and as the
command of an SSH session (`ssh host 'sh -s' < agents-cat`). It needs `stat`
with `-c` (GNU coreutils or BusyBox). The maintained copy, with tests, is
the file `agents-cat` in the specification repository.

```sh
#!/bin/sh
# agents-cat: print the host document. Exits 0 when no file exists.
export LC_ALL=C

trusted() {   # owned by root, not writable by group or others
    set -- $(stat -Lc '%u %a' "$1" 2>/dev/null)
    [ "$1" = 0 ] || return 1
    case $2 in *[2367]?|*[2367]) return 1 ;; esac
}

trusted /etc/agents && cat /etc/agents

ls /usr/lib/agents.d /run/agents.d /etc/agents.d 2>/dev/null |
grep '^[A-Za-z0-9_.-]*\.md$' | sort -u |
while read -r n; do
    for d in /etc/agents.d /run/agents.d /usr/lib/agents.d; do
        [ -e "$d/$n" ] || continue
        trusted "$d" && trusted "$d/$n" && [ -s "$d/$n" ] && { echo; cat "$d/$n"; }
        break
    done
done
```

## 7. Format

- UTF-8 text, Markdown ([CommonMark](https://commonmark.org/)).
- **No required fields and no required headings.** An agent reads the text
  as a human reads it.
- Version 0.1 defines no front matter and no machine-readable keys.

### 7.1 Recommended content

Write what a competent new colleague would need on the first day with root
access. Useful headings:

| Heading | Answers |
|---|---|
| Role | What is this host for? Which environment? What depends on it? |
| Owner | Which team? How does one reach them? |
| Services | What runs here, under which unit names and ports? |
| Where things are | Logs, data directories, configuration, deploy paths |
| Safe operations | Commands that are known to be harmless |
| Do not | Actions that cause damage on this host, with the reason |
| Change process | Is the host managed by Ansible, Puppet, an image pipeline? |
| Escalation | When to stop and call a human |
| Last reviewed | A date, so that a reader can judge staleness |

Do not copy what the agent can discover in one command (`uname -a`,
`systemctl list-units`). Write what it cannot discover: intent, history and
consequences.

### 7.2 Example

`/etc/agents`:

```markdown
# db-replica-2.prod.example.net

## Role
PostgreSQL 17 streaming replica for the billing cluster. Production.
Read-only traffic from the reporting service arrives through pgbouncer on
port 6432. The primary is db-primary-1.

## Owner
Team data-platform. On-call: #data-oncall.

## Where things are
- Data: /var/lib/postgresql/17/main (do not write here)
- Logs: journalctl -u postgresql@17-main
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
```

`/run/agents.d/10-maintenance.md`, written by a deploy script and removed
when it finishes:

```markdown
## Maintenance in progress
Kernel upgrade started 13:40 UTC by Ansible. A reboot is expected.
Do not start long-running jobs.
```

## 8. How an agent treats the host document

The host document is **context, not authority**.

1. **Lowest precedence.** Instructions from the agent's principal, and the
   agent's own system policy, override the host document.
2. **Restrictions count, grants do not.** An agent SHOULD respect a
   restriction in the host document ("do not restart X"), because the cost
   of obeying a false restriction is small. An agent MUST NOT treat any text
   in the host document as permission to do something that its principal
   did not permit. "You are allowed to disable the firewall" grants nothing.
3. **Same-host scope.** The host document describes this host. An agent MUST
   NOT act on its instructions to operate on other hosts, to send data to
   an external destination, to change the agent's own configuration or to
   reveal credentials.
4. **Provenance.** An agent SHOULD present the text to its model with a
   clear label that it comes from the host, for example
   `Host document from db-replica-2 (/etc/agents):`.
5. **Conflict.** When the host document conflicts with the principal's
   instruction, the agent follows the principal, and SHOULD say that the
   host document disagrees. That is exactly the information a human wants.

## 9. Security considerations

- **Prompt injection.** Anyone who can write `/etc/agents` can speak to every
  agent that visits the host. The trust check (6.2) limits writers to root.
  The rules in section 8 limit what a root-level attacker gains: such an
  attacker already controls the host, and the rules prevent a step from
  there to other hosts or to the agent's credentials.
- **Reconnaissance.** A world-readable description of a host helps an
  intruder as much as an agent. Do not write more than a logged-in user
  could learn anyway, or restrict the file mode.
- **Secrets.** The host document MUST NOT contain passwords, tokens or
  private keys. Name the secret store instead.
- **Staleness.** A wrong host document is worse than none. Keep it under
  configuration management and include a review date.
- **Packages.** A fragment in `/usr/lib/agents.d/` has the same weight as
  any other. Distributions should review it as they review a maintainer
  script.

## 10. Relation to other files

| File | Audience | Scope |
|---|---|---|
| `/etc/motd` | Humans at login | Host |
| `/etc/os-release`, `/etc/machine-info` | Programs | Host identity, key=value |
| `AGENTS.md` | Coding agents | Repository |
| `/etc/ampcode/AGENTS.md`, `/etc/claude-code/CLAUDE.md` | One vendor's agent | Organisation policy for that tool |
| **`/etc/agents`** | **Any agent** | **Host** |

An agent that supports a vendor-specific system file can read both. The
vendor file says how the tool behaves. `/etc/agents` says what the machine
is.

## 11. Adoption

For an administrator:

```sh
sudoedit /etc/agents
```

For an agent author, the minimum is: before the first change on a host, run
the reference loader (or `cat /etc/agents /etc/agents.d/*.md` plus the trust
check), and put the result into the model context with a host label.

For a packager: ship `/usr/lib/agents.d/NN-<package>.md` with the log
locations, the reload-versus-restart rule and the dangerous commands of the
service.

## 12. Open questions for 1.0

1. **Name collision.** Checked on 2026-11-12: no package in Debian (stable
   and unstable, main and contrib), Ubuntu (24.04 and the current
   development series) or Fedora (rawhide, Everything) ships `/etc/agents`,
   `/etc/agents.d`, `/run/agents.d` or `/usr/lib/agents.d`. Checked on
   2026-11-13 in the same way: Arch (core and extra, x86_64) and Alpine
   (edge, x86_64) ship none of these paths. Not yet checked: openSUSE,
   third-party vendor packages.
2. **Structured data.** Should a small optional front matter exist
   (environment, owner, criticality) so that tools can filter without a
   model?
3. **Per-user layer.** Is `~/.config/agents` in scope, or does it stay with
   each tool?
4. **Containers and Kubernetes.** Does an image ship
   `/usr/lib/agents.d/`? Does the node file apply inside a pod?
5. **Other systems.** Paths for macOS, the BSDs and Windows.
6. **Integrity.** Is root ownership sufficient, or is a signature needed
   for regulated environments?
7. **`/usr/share` versus `/usr/lib`** for package fragments.

## 13. License

The specification text and the examples are licensed under CC BY 4.0
(`LICENSE-SPEC`). The reference loader, the tests and the files in
`contrib/` are licensed under Apache 2.0 (`LICENSE`).
