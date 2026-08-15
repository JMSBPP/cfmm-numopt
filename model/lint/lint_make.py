#!/usr/bin/env python3
"""GATE-01 criterion 3 — the third instrument.

`make lint-make` does not trust the author of the recipes it reviews. It asks
GNU make itself which recipe bodies are live (`make --print-data-base`), so a
recipe cannot escape review by not being mentioned here, normalises each body
from make syntax to sh, and then submits it to two structural checks and to
shellcheck.

Structural checks
-----------------
LM-GREP-PREDICATE  a pattern match standing in a pass/fail position. The
                   pass/fail predicate of a gating recipe must be a process
                   exit code. Extracting error TEXT for a message, after the
                   decision has been made, is fine and is not reported.
LM-SET-E           a compound recipe line that does not declare `set -e`.
                   Without it a failing statement mid-line is skipped and the
                   recipe's exit status is that of its LAST statement.

shellcheck leg
--------------
Restricted to SC2181 (check the exit code directly, not via $?) and SC2015
(`a && b || c` is not if-then-else) — the two classes that produce exactly the
false-pass shape this phase exists to remove. shellcheck being ABSENT is a
failure, never a skip.

Modes
-----
  (no args)          parse the live tree via `make -pRrq`
  --file <path.mk>   parse one raw .mk file (used by the TEST-09 mutants)
"""
import fnmatch
import os
import re
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO_ROOT, "model", "build", "lint-make")

RECIPE_SRC_RE = re.compile(r"^#  recipe to execute \(from '([^']+)', line (\d+)\):")
TARGET_RE = re.compile(r"^([^#\s][^:=]*?):(?!=)")
MAKEVAR_RE = re.compile(r"\$[({]([A-Za-z_][A-Za-z0-9_]*)[)}]")
MAKEFUNC_RE = re.compile(r"\$[({][^(){}]*[)}]")

# LM-GREP-PREDICATE: a pattern match occupying a pass/fail position.
PREDICATE_PATTERNS = [
    re.compile(r"\bif\b[^\n]*\bgrep\b[^\n]*;[ \t]*then"),
    re.compile(r"\bif\b[^\n]*![ \t]*grep\b"),
    re.compile(r"\b(?:while|until)\b[^\n]*\bgrep\b"),
    re.compile(r"\bgrep\b[^|\n]*(?:&&|\|\|)"),
    re.compile(r"^[ \t]*[A-Za-z_][A-Za-z0-9_]*=[^\n]*\bgrep\b"),
]
PREDICATE_MSG = ("grep used as a pass/fail predicate in a gating recipe "
                 "- gate on the exit code (GATE-01)")

COMPOUND_KEYWORD_RE = re.compile(r"\b(?:for|if|while|until|case)\b")
SET_E_RE = re.compile(r"^[ \t]*set -e[ \t]*(?:;|$)")
SET_E_MSG = "compound recipe line does not declare 'set -e'"


def in_scope(src):
    """Only the root Makefile and mk/*.mk are reviewed."""
    return src == "Makefile" or fnmatch.fnmatch(src, "mk/*.mk")


def parse_live():
    """Ask make which recipe bodies are live. Its return code is meaningless
    here (-q reports out-of-dateness), so it is deliberately ignored."""
    proc = subprocess.run(
        ["make", "--print-data-base", "--question",
         "--no-builtin-rules", "--no-builtin-variables"],
        cwd=REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        universal_newlines=True)
    lines = proc.stdout.split("\n")
    recipes = []
    target = None
    i = 0
    while i < len(lines):
        line = lines[i]
        m = RECIPE_SRC_RE.match(line)
        if m:
            src = m.group(1)
            body = []
            i += 1
            while i < len(lines) and lines[i].startswith("\t"):
                body.append(lines[i])
                i += 1
            if target is not None and in_scope(src) and body:
                recipes.append((src, target, "\n".join(body)))
            continue
        t = TARGET_RE.match(line)
        if t and not line.startswith("\t"):
            target = t.group(1).strip()
        i += 1
    return recipes


def parse_file(path):
    """Parse `target:` + TAB-indented body straight out of a raw .mk file."""
    rel = os.path.relpath(os.path.abspath(path), REPO_ROOT)
    with open(path) as fh:
        lines = fh.read().split("\n")
    recipes = []
    i = 0
    while i < len(lines):
        line = lines[i]
        t = TARGET_RE.match(line)
        if t and not line.startswith("\t"):
            target = t.group(1).strip()
            body = []
            i += 1
            while i < len(lines) and lines[i].startswith("\t"):
                body.append(lines[i])
                i += 1
            if body:
                recipes.append((rel, target, "\n".join(body)))
            continue
        i += 1
    return recipes


def normalise(body):
    """make recipe body -> sh. Order matters: `$$` is protected first, so a
    shell command substitution is never mistaken for a make function."""
    out = []
    for line in body.split("\n"):
        if line.startswith("\t"):
            line = line[1:]
        if line[:1] in ("@", "-", "+"):
            line = line[1:]
        out.append(line)
    text = "\n".join(out)
    text = text.replace("$$", "\x00")
    text = MAKEVAR_RE.sub(lambda m: "MAKEVAR_" + m.group(1), text)
    prev = None
    while prev != text:
        prev = text
        text = MAKEFUNC_RE.sub("MAKEFUNC", text)
    text = text.replace("\x00", "$")
    return text


def logical_lines(text):
    """Split on newlines NOT preceded by a backslash, then fold each
    continuation back into a single string."""
    for chunk in re.split(r"(?<!\\)\n", text):
        yield chunk.replace("\\\n", " ")


def structural_findings(text):
    findings = []
    for ll in logical_lines(text):
        if not ll.strip():
            continue
        for pat in PREDICATE_PATTERNS:
            if pat.search(ll):
                findings.append(("LM-GREP-PREDICATE", PREDICATE_MSG))
                break
        compound = (";" in ll or "&&" in ll or "||" in ll
                    or COMPOUND_KEYWORD_RE.search(ll) is not None)
        if compound and not SET_E_RE.match(ll):
            findings.append(("LM-SET-E", SET_E_MSG))
    return findings


def resolve_shellcheck(value):
    if not value:
        return None
    if os.path.sep in value:
        cand = value if os.path.isabs(value) else os.path.join(REPO_ROOT, value)
        return cand if os.path.isfile(cand) and os.access(cand, os.X_OK) else None
    for d in os.environ.get("PATH", "").split(os.pathsep):
        cand = os.path.join(d, value)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def main():
    args = sys.argv[1:]
    if args and args[0] == "--file":
        if len(args) < 2:
            sys.stderr.write("usage: lint_make.py [--file <path.mk>]\n")
            return 2
        recipes = parse_file(args[1])
    elif args:
        sys.stderr.write("usage: lint_make.py [--file <path.mk>]\n")
        return 2
    else:
        recipes = parse_live()

    if not recipes:
        print("lint-make FAIL: no recipe bodies were extracted - "
              "a review of nothing is not a review")
        return 1

    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)

    findings = []
    script_of = {}
    for src, target, body in recipes:
        text = normalise(body)
        for code, msg in structural_findings(text):
            findings.append("%s:%s: %s %s" % (src, target, code, msg))
        path = os.path.join(OUT_DIR, "%s.sh" % target.replace("/", "_"))
        with open(path, "w") as fh:
            fh.write("#!/bin/sh\n" + text + "\n")
        script_of[path] = (src, target)

    sc_value = os.environ.get("SHELLCHECK", "shellcheck")
    codes = os.environ.get("SHELLCHECK_CODES", "SC2181,SC2015")
    sc = resolve_shellcheck(sc_value)
    if sc is None:
        print("lint-make FAIL: shellcheck not found at '%s' - "
              "run 'make tools-shellcheck'" % sc_value)
        return 1

    scripts = sorted(script_of)
    proc = subprocess.run([sc, "-s", "sh", "--include=" + codes, "-f", "gcc"] + scripts,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          universal_newlines=True)
    for line in proc.stdout.split("\n"):
        if line.strip():
            findings.append(line.strip())
    if proc.returncode not in (0, 1):
        findings.append("shellcheck exited %d" % proc.returncode)

    for f in findings:
        print(f)
    print("lint-make: %d recipes, %d findings" % (len(recipes), len(findings)))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
