# /etc/agents

**`motd` for AI agents.** One file that tells an agent what a Linux host is
and how to work on it safely.

```sh
cat /etc/agents
```

An agent that lands on your server knows nothing about it. It does not know
that this is a production replica, where the logs are, or which restart
drops live traffic. `/etc/agents` is the place to tell it: plain Markdown,
owned by root, readable by any agent, local or over SSH.

- Site: <https://etc-agents.org/>
- Specification: [SPEC.md](SPEC.md) (v0.1, draft)
- Reference loader: [agents-cat](agents-cat) (POSIX shell, 30 lines)
- Examples: [examples/](examples/)

## Quick start

Write the file:

```sh
sudoedit /etc/agents
```

```markdown
# db-replica-2.prod.example.net

## Role
PostgreSQL 17 streaming replica for billing. Production.

## Do not
- Do not restart postgresql between 06:00 and 08:00 UTC. Nightly reports
  run then, and a restart makes them fail without an alert.
- Do not run `pg_ctl promote`. Promotion needs the failover runbook.

## Escalation
Replication lag above 10 minutes: stop and page #data-oncall.
```

That is a complete, conforming host. Everything else is optional.

## Layout

| Path | Written by | For |
|---|---|---|
| `/etc/agents` | Administrator | The main description of the host |
| `/etc/agents.d/*.md` | Administrator, Ansible, Puppet | Site-specific fragments |
| `/run/agents.d/*.md` | Scripts, at runtime | Temporary state: "maintenance until 14:00 UTC" |
| `/usr/lib/agents.d/*.md` | Packages | How a packaged service is operated |

The same file name in `/etc` overrides `/run`, which overrides `/usr/lib`.
An empty file or a link to `/dev/null` in `/etc/agents.d/` disables a
fragment. If you know systemd drop-ins, you already know this.

## The rules that matter

1. **Root only.** An agent skips any file that is not owned by root or that
   group or others can write.
2. **Context, not authority.** The file informs the agent. It does not
   replace sudo rules, permissions or sandboxes.
3. **Restrictions count, grants do not.** "Do not restart X" is respected.
   "You may disable the firewall" grants nothing.
4. **This host only.** The file cannot send an agent to other hosts, to an
   external URL, or to its own credentials.
5. **No secrets.** Name the secret store. Do not paste the secret.

## For agent authors

Before the first state-changing command on a host, run the loader and put
the output into the model context with a label that names the host:

```sh
ssh host 'sh -s' < agents-cat
```

Then follow [SPEC.md section 8](SPEC.md#8-how-an-agent-treats-the-host-document).
Tell us when your agent reads the file, and we add it to the list below.

## Implementations

None listed yet. Open a pull request to add yours.

## FAQ

**Why not `/etc/AGENTS.md`?**
Files in `/etc` are lowercase and have no document extension: `motd`,
`hosts`, `fstab`, `issue`. A file that looks at home is a file that
administrators accept.

**Why not put an AGENTS.md in `/`?**
[AGENTS.md](https://agents.md/) describes a repository: build steps, tests,
code style. A host is not a repository. It has an owner, a role and
consequences, and `/etc` is where a host keeps facts about itself.

**My agent already reads `/etc/<vendor>/...`. Why another file?**
The vendor file configures one tool. `/etc/agents` describes the machine,
once, for every tool. Read both.

**Is this a prompt-injection hole?**
Only root can write a file that agents accept, and root already controls
the host. The specification also stops the next step: the file cannot grant
permissions, and it cannot direct an agent to other hosts or to its
credentials. See [SPEC.md section 9](SPEC.md#9-security-considerations).

**Why Markdown and not YAML?**
The reader is a language model, and the most useful content is the reason
behind a rule. Prose carries reasons. Structured keys are an open question
for 1.0.

**Does the agent obey the file?**
The file is advice with a clear scope, not enforcement. Use sudo rules and
permissions for what must never happen.

**What do I write in it?**
What a competent new colleague needs on day one with root access, and
cannot discover with one command: intent, history and consequences.

## Tests

```sh
sh tests/run.sh
```

## License

Specification text and examples: [CC BY 4.0](LICENSE-SPEC). Loader, tests
and `contrib/`: [Apache 2.0](LICENSE).

## Status

Draft. Comments and objections are welcome as issues. See
[CONTRIBUTING.md](CONTRIBUTING.md).
