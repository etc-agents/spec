# Contributing

The specification is a draft. The most useful contributions now:

1. **Objections.** Open an issue that says what breaks, on which system,
   for which agent. Section 12 of [SPEC.md](SPEC.md) lists the known open
   questions.
2. **Implementations.** If your agent reads `/etc/agents`, add it to the
   list in [README.md](README.md) with a link to the code or the docs.
3. **Examples.** Add a host file to `examples/hosts/` or a service fragment
   to `examples/agents.d/`. Good examples say what an agent cannot discover
   by itself, and give the reason for each rule. Remove real host names,
   addresses and people.
4. **Loader fixes.** `agents-cat` must stay POSIX shell and must stay
   short. Each change needs a test in `tests/run.sh`.

## Changes to the specification

- One topic per pull request.
- Say which section changes and why. Name the alternative that you
  rejected.
- A change that weakens section 6.2 (trust check) or section 8 (context,
  not authority) needs a threat description.

## Style

Short sentences. Normative words (MUST, SHOULD, MAY) only where a reader
has to act on them.
