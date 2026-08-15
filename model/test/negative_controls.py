#!/usr/bin/env python3
"""TEST-09 negative-control runner.

The pass/fail predicate is the PROCESS EXIT CODE and nothing else. No output
scraping, no pattern-matching on a listing file -- that is the idiom this phase
exists to remove, and this runner is checked for it by acceptance criterion.
Reading the registry file is input handling, not a predicate.

Registry schema (TSV, one entry per line, append-only, '#' starts a comment):

    id <TAB> kind <TAB> expect <TAB> command <TAB> claim

  id      unique slug, [A-Za-z0-9._-]+
  kind    'negative' (the command MUST fail) or 'positive' (it MUST succeed)
  expect  'nonzero' (negative rows only) or an exact integer return code
  command sh command, executed with cwd = repository root
  claim   the "X reddens when Y breaks" sentence this row discharges
"""
import os
import re
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TIMEOUT = int(os.environ.get("NC_TIMEOUT", "900"))
ID_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def die(msg):
    sys.stderr.write("negative-controls FAIL: %s\n" % msg)
    sys.exit(2)


def load(path):
    if not os.path.exists(path):
        die("registry %s does not exist" % path)
    rows, seen = [], set()
    with open(path) as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 5:
                die("%s:%d malformed: expected 5 tab-separated fields, got %d"
                    % (path, lineno, len(parts)))
            rid, kind, expect, cmd, claim = [p.strip() for p in parts]
            if not ID_RE.match(rid):
                die("%s:%d bad id %r" % (path, lineno, rid))
            if rid in seen:
                die("%s:%d duplicate id %r" % (path, lineno, rid))
            seen.add(rid)
            if kind not in ("negative", "positive"):
                die("%s:%d kind must be negative|positive, got %r" % (path, lineno, kind))
            if expect == "nonzero":
                if kind != "negative":
                    die("%s:%d expect=nonzero is only valid for kind=negative" % (path, lineno))
            else:
                try:
                    int(expect)
                except ValueError:
                    die("%s:%d expect must be 'nonzero' or an integer, got %r"
                        % (path, lineno, expect))
            if not cmd:
                die("%s:%d empty command" % (path, lineno))
            rows.append((rid, kind, expect, cmd, claim))
    if not rows:
        die("registry %s contains no entries — an empty registry is a false pass" % path)
    return rows


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "model/test/_mutants/registry.tsv"
    rows = load(path)
    failures = 0
    for rid, kind, expect, cmd, claim in rows:
        try:
            rc = subprocess.call(["sh", "-c", cmd], cwd=REPO_ROOT, timeout=TIMEOUT)
            timed_out = False
        except subprocess.TimeoutExpired:
            rc, timed_out = None, True
        if timed_out:
            ok = False
        elif expect == "nonzero":
            ok = rc != 0
        else:
            ok = rc == int(expect)
        print("%-4s %-38s kind=%-8s expect=%-8s rc=%s"
              % ("PASS" if ok else "FAIL", rid, kind, expect,
                 "TIMEOUT" if timed_out else rc))
        if not ok:
            failures += 1
            print("       claim: %s" % claim)
            print("       cmd:   %s" % cmd)
    print("\nnegative-controls: %d entries, %d failed" % (len(rows), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
