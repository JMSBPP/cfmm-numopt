#!/usr/bin/env python3
"""GATE-02 / GATE-03 / GATE-04 -- the GAMS source lint.

The rule table is a DATA FILE (`model/lint/rules.tsv`), not a fork point in this
script. A later phase adds coverage by APPENDING A LINE to that file; it never
edits this engine. That is the M7 append-only concurrency substrate: two plans
adding a rule each touch two different lines of one file.

Two rule kinds
--------------
forbid          any line matching `pattern` is a violation.
require_within  a line matching `pattern` must be followed, within `window`
                following lines, by a line matching `partner`.

`require_within` exists because the GATE-03 defect is not a forbidden token but
a MISSING assertion: a `Solve` whose status codes are displayed rather than
tested. The partner regex therefore has to look inside the `abort$(...)`
CONDITION -- a partner that merely finds the token in the window is satisfied by
a display argument, which is the very defect class being removed.

Refusal-first, like `negative_controls.py`: an empty rule table, a malformed
rule, an unreadable regex, or an empty file set all exit 2. A lint that scanned
nothing, or applied nothing, must never report green.

The pass/fail predicate is this process's own exit code. Pattern matching is
done in-process on the source text; no external matching tool is spawned.

Usage
-----
  lint_gams.py [--rules FILE] [PATH ...]

With no PATH the file set is every `*.gms` under `model/`, excluding
`model/build/` (generated) and `model/test/_mutants/` (deliberately broken).
With PATHs, exactly those files are scanned -- this is how the TEST-09 mutants
are driven.
"""
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCAN_ROOT = os.path.join(REPO_ROOT, "model")
EXCLUDED = (
    os.path.join("model", "build") + os.sep,
    os.path.join("model", "test", "_mutants") + os.sep,
)

KINDS = ("forbid", "require_within")
SEVERITIES = ("error", "warn")
NFIELDS = 7


class RuleError(Exception):
    pass


class Rule(object):
    def __init__(self, rid, severity, kind, pattern, partner, window, message):
        self.id = rid
        self.severity = severity
        self.kind = kind
        self.pattern = pattern
        self.partner = partner
        self.window = window
        self.message = message


def _compile(where, expr):
    try:
        return re.compile(expr)
    except re.error as exc:
        raise RuleError("%s: uncompilable regex %r (%s)" % (where, expr, exc))


def load_rules(path):
    """Parse the TSV rule table. Every failure mode is fatal, never a skip."""
    if not os.path.exists(path):
        raise RuleError("rule table '%s' does not exist" % path)
    rules = []
    seen = set()
    with open(path) as fh:
        for lineno, raw in enumerate(fh.read().split("\n"), 1):
            line = raw.rstrip("\r")
            if not line.strip() or line.lstrip()[:1] == "#":
                continue
            fields = line.split("\t")
            where = "%s:%d" % (path, lineno)
            if len(fields) != NFIELDS:
                raise RuleError(
                    "%s: expected %d TAB-separated fields, found %d"
                    % (where, NFIELDS, len(fields)))
            rid, severity, kind, pattern, partner, window, message = fields
            rid = rid.strip()
            severity = severity.strip()
            kind = kind.strip()
            window = window.strip()
            if not rid:
                raise RuleError("%s: empty rule id" % where)
            if rid in seen:
                raise RuleError("%s: duplicate rule id '%s'" % (where, rid))
            seen.add(rid)
            if severity not in SEVERITIES:
                raise RuleError("%s: unknown severity '%s' (expected one of %s)"
                                % (where, severity, "/".join(SEVERITIES)))
            if kind not in KINDS:
                raise RuleError("%s: unknown kind '%s' (expected one of %s)"
                                % (where, kind, "/".join(KINDS)))
            if not pattern:
                raise RuleError("%s: empty pattern" % where)
            if not message.strip():
                raise RuleError("%s: empty message" % where)
            trigger = _compile(where, pattern)
            if kind == "forbid":
                if partner or window:
                    raise RuleError(
                        "%s: kind=forbid takes no partner/window" % where)
                rules.append(Rule(rid, severity, kind, trigger, None, 0, message))
            else:
                if not partner:
                    raise RuleError("%s: kind=require_within needs a partner" % where)
                if not window.isdigit() or int(window) < 1:
                    raise RuleError("%s: window must be a positive integer, got '%s'"
                                    % (where, window))
                rules.append(Rule(rid, severity, kind, trigger,
                                  _compile(where, partner), int(window), message))
    if not rules:
        raise RuleError("rule table '%s' is empty - an empty rule table is a "
                        "false pass, not a pass" % path)
    return rules


def default_files():
    """Every .gms under model/, minus generated output and the mutants.

    The walk is deliberately filesystem-based rather than index-based: a source
    that has been written but not yet committed is still a source, and must not
    escape the lint by being untracked.
    """
    found = []
    for dirpath, dirnames, filenames in os.walk(SCAN_ROOT):
        dirnames.sort()
        rel_dir = os.path.relpath(dirpath, REPO_ROOT) + os.sep
        if any(rel_dir.startswith(x) for x in EXCLUDED):
            dirnames[:] = []
            continue
        for name in sorted(filenames):
            if name.endswith(".gms"):
                found.append(os.path.relpath(os.path.join(dirpath, name), REPO_ROOT))
    return sorted(found)


def scan(path, rules, violations):
    full = path if os.path.isabs(path) else os.path.join(REPO_ROOT, path)
    with open(full, errors="replace") as fh:
        lines = fh.read().split("\n")
    for idx, line in enumerate(lines):
        for rule in rules:
            if not rule.pattern.search(line):
                continue
            if rule.kind == "forbid":
                violations.append((path, idx + 1, rule, line))
            else:
                window_text = "\n".join(lines[idx + 1:idx + 1 + rule.window])
                if not rule.partner.search(window_text):
                    violations.append((path, idx + 1, rule, line))


def main():
    argv = sys.argv[1:]
    rules_path = os.path.join("model", "lint", "rules.tsv")
    paths = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--rules":
            if i + 1 >= len(argv):
                sys.stderr.write("lint-gams FAIL: --rules needs a value\n")
                return 2
            rules_path = argv[i + 1]
            i += 2
            continue
        if arg.startswith("--"):
            sys.stderr.write("usage: lint_gams.py [--rules FILE] [PATH ...]\n")
            return 2
        paths.append(arg)
        i += 1

    try:
        rules = load_rules(rules_path)
    except RuleError as exc:
        sys.stderr.write("lint-gams FAIL: %s\n" % exc)
        return 2

    if paths:
        files = []
        for p in paths:
            full = p if os.path.isabs(p) else os.path.join(REPO_ROOT, p)
            if not os.path.isfile(full):
                sys.stderr.write("lint-gams FAIL: '%s' does not exist\n" % p)
                return 2
            files.append(p)
    else:
        files = default_files()

    if not files:
        sys.stderr.write("lint-gams FAIL: no .gms files to scan - a lint that "
                         "scanned nothing must not report green\n")
        return 2

    violations = []
    for path in files:
        scan(path, rules, violations)

    violations.sort(key=lambda v: (v[0], v[1], v[2].id))
    for path, lineno, rule, line in violations:
        print("%s:%d: %s %s %s" % (path, lineno, rule.id, rule.severity, rule.message))
        print("    %s" % line.strip())
    print("lint-gams: %d files, %d rules, %d violations"
          % (len(files), len(rules), len(violations)))
    return 1 if any(v[2].severity == "error" for v in violations) else 0


if __name__ == "__main__":
    sys.exit(main())
