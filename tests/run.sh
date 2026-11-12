#!/bin/sh
# Tests for agents-cat. Run as root, or as a normal user on a kernel that
# permits unprivileged user namespaces (the script then re-executes itself
# inside one, so that the test files appear to be owned by uid 0).
#
#   sh tests/run.sh            # dash/bash/busybox: SH=busybox\ sh sh tests/run.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
cat_bin=$here/../agents-cat
SH=${SH:-sh}

if [ "$(id -u)" != 0 ]; then
    if unshare -r true 2>/dev/null; then
        exec unshare -r sh "$0" "$@"
    elif command -v bwrap >/dev/null; then
        exec bwrap --unshare-user --uid 0 --gid 0 --bind / / --dev /dev sh "$0" "$@"
    fi
    echo "need root, unshare -r or bwrap" >&2; exit 2
fi

fail=0
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

new_root() {
    R=$T/$1
    mkdir -p "$R/etc/agents.d" "$R/run/agents.d" "$R/usr/lib/agents.d"
    chmod 755 "$R/etc/agents.d" "$R/run/agents.d" "$R/usr/lib/agents.d"
}
put() { printf '%s\n' "$2" > "$1"; chmod "${3:-644}" "$1"; }
check() {   # name, expected output
    got=$(AGENTS_ROOT=$R $SH "$cat_bin"); rc=$?
    if [ "$rc" = 0 ] && [ "$got" = "$2" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1 (exit $rc)"; echo "--- expected"; echo "$2"; echo "--- got"; echo "$got"
        fail=1
    fi
}
NL='
'

new_root empty
check "no files: empty output, exit 0" ""

new_root main
put "$R/etc/agents" MAIN
check "main file only" "MAIN"

new_root frag
put "$R/etc/agents.d/20-b.md" B
put "$R/etc/agents.d/10-a.md" A
check "fragments only, byte order" "${NL}A${NL}${NL}B"

new_root order
put "$R/etc/agents" MAIN
put "$R/usr/lib/agents.d/50-pg.md" "pg vendor"
put "$R/run/agents.d/10-maint.md" "maintenance"
put "$R/etc/agents.d/90-site.md" "site"
check "main, then all directories merged by name" \
    "MAIN${NL}${NL}maintenance${NL}${NL}pg vendor${NL}${NL}site"

new_root override
put "$R/usr/lib/agents.d/50-x.md" "usr"
put "$R/run/agents.d/50-x.md" "run"
check "/run wins over /usr/lib" "${NL}run"
put "$R/etc/agents.d/50-x.md" "etc"
check "/etc wins over /run" "${NL}etc"

new_root mask
put "$R/usr/lib/agents.d/50-x.md" "usr"
ln -s /dev/null "$R/etc/agents.d/50-x.md"
check "symlink to /dev/null masks" ""
rm "$R/etc/agents.d/50-x.md"; : > "$R/etc/agents.d/50-x.md"; chmod 644 "$R/etc/agents.d/50-x.md"
check "empty file masks" ""

new_root names
put "$R/etc/agents.d/readme.txt" "txt"
put "$R/etc/agents.d/has space.md" "space"
put "$R/etc/agents.d/ok_1.md" "ok"
check "ignores non-.md and bad names" "${NL}ok"

new_root wfile
put "$R/etc/agents" MAIN 666
put "$R/etc/agents.d/10-a.md" A 664
put "$R/etc/agents.d/20-b.md" B 644
check "skips group/world-writable files" "${NL}B"

new_root wmask
put "$R/usr/lib/agents.d/50-x.md" "usr"
put "$R/etc/agents.d/50-x.md" "evil" 666
check "untrusted file still masks lower directories" ""

new_root wdir
put "$R/etc/agents.d/10-a.md" A
chmod 777 "$R/etc/agents.d"
check "skips fragments in a writable directory" ""

new_root sticky
put "$R/etc/agents.d/10-a.md" A
chmod 1755 "$R/etc/agents.d"
check "four-digit mode without group/other write is trusted" "${NL}A"

new_root link
put "$R/usr/lib/agents.d/real.md" "target"
ln -s ../../usr/lib/agents.d/real.md "$R/etc/agents.d/10-link.md"
rm "$R/usr/lib/agents.d/real.md"; put "$R/etc/real-target" "target"
ln -sf ../real-target "$R/etc/agents.d/10-link.md"
check "follows a symlink to a trusted file" "${NL}target"
chmod 666 "$R/etc/real-target"
check "checks the symlink target, not the link" ""

# Owner test. Real root can chown. In a user namespace, files of the real
# root (/etc/passwd) appear with the overflow uid, which is also not 0.
new_root owner
put "$R/etc/agents" MAIN
if chown 1 "$R/etc/agents" 2>/dev/null; then
    check "skips a file not owned by uid 0" ""
elif [ "$(stat -Lc %u /etc/passwd)" != 0 ]; then
    ln -sf /etc/passwd "$R/etc/agents"
    check "skips a file not owned by uid 0" ""
else
    echo "skip owner test (no file with another uid available)"
fi

exit $fail
