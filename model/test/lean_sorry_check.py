#!/usr/bin/env python3
"""GATE-07 -- the Lean proof gate that can actually SEE the declarations it gates.

  lean_sorry_check.py <lean-file> <declaration-id>

Exit contract (published by model/test/lean_sorry_check.sh in plan 00-02 and
preserved here byte for byte):

  0  the declaration was found and its body contains no sorry/admit
  1  the declaration was found and its body contains sorry or admit
  2  the declaration was not found in the file
  3  usage / file error

Why this exists
---------------
The previous implementation was `grep -nE "^theorem $ID"`. That is column-0
anchored and matches ONLY the keyword `theorem`. Measured across the twelve
`lean4-spec/vol_markets/*.lean` modules, SIX of them -- FeeSchedule (24
declarations), VolInstrument (36), RiskDesign (21), Flow (12), PosSpec (12) and
GeomProfile (11) -- declare ZERO `theorem`s: every one of their results is a
`lemma`. The gate therefore matched none of them, and reported "declaration not
found" (rc=2) rather than a proof result. The mechanism is the KEYWORD, not the
indentation: the measured count of INDENTED theorems across those files is 0.

Three defects are fixed here:

1. `lemma` (and `def`/`abbrev`/`instance`/`example`) are matched as well as
   `theorem`, at any indentation, with attributes and modifiers allowed.
2. Namespaces are tracked, so a declaration can be addressed by its bare name or
   by its fully-qualified name. Matching is EXACT in both cases -- never a prefix
   match, because a prefix match is exactly how a rename goes undetected.
3. Body extent terminates at the next construct whose indentation is <= the
   declaration's. The old `awk` terminated only on COLUMN-0 constructs, so a
   `sorry` in a later, more-indented declaration was attributed to an earlier,
   clean one.

Comment stripping runs before the `sorry` search: `/- ... -/` blocks (including
`/-- ... -/` doc comments) first, then `--` to end of line. This is load-bearing:
`lean4-spec/exp/eta.lean:602` contains the word `sorry` in backticks inside a doc
comment ("Substantive; left as `sorry` for Aristotle"), and it is the ONLY
occurrence of the token in the whole submodule. Without stripping, every positive
control over eta.lean would falsely redden.

Because the tree contains no real `sorry`, a scan of it can never demonstrate
that this gate fires. `model/test/_mutants/lean/SorryFixture.lean` is the only
artifact that can, and it is registered in model/test/_mutants/registry.tsv.
"""
import re
import sys

# A declaration line: optional attributes, optional modifiers, a keyword, a name.
DECL_RE = re.compile(
    r"^(?P<indent>[ \t]*)"
    r"(?:@\[[^\]]*\][ \t]*)?"
    r"(?:(?:private|protected|nonrec|noncomputable|partial|unsafe|scoped|local)[ \t]+)*"
    r"(?P<kw>theorem|lemma|def|abbrev|instance|example)[ \t]+"
    r"(?P<name>[^\s({\[:]+)")

# Anything that starts a new construct and therefore ends the previous body.
CONSTRUCT_RE = re.compile(
    r"^[ \t]*(?:@\[|private[ \t]|protected[ \t]|nonrec[ \t]|noncomputable[ \t]|"
    r"partial[ \t]|unsafe[ \t]|scoped[ \t]|local[ \t]|"
    r"theorem[ \t]|lemma[ \t]|def[ \t]|abbrev[ \t]|instance[ \t]|example[ \t]|"
    r"structure[ \t]|inductive[ \t]|namespace[ \t]|end\b|section\b|open[ \t]|"
    r"import[ \t]|variable[ \t]|universe[ \t])")

NAMESPACE_RE = re.compile(r"^[ \t]*namespace[ \t]+(\S+)")
END_RE = re.compile(r"^[ \t]*end[ \t]+(\S+)")
SORRY_RE = re.compile(r"\bsorry\b|\badmit\b")


def strip_comments(text):
    """Blank out comments, preserving line count AND column positions.

    Every comment character becomes a space, so line numbers reported to the
    operator still refer to the real file. Block comments (`/- -/`, which covers
    `/-- -/` doc comments) are removed first, non-greedily, across newlines; then
    `--` to end of line on what survives.

    Returns (clean_text, block_open_lines) where block_open_lines is the set of
    1-based line numbers on which a block comment OPENS. Those lines still count
    as construct boundaries -- a doc comment introduces the declaration that
    follows it -- even though their content has been blanked.
    """
    block_open_lines = set()
    out = list(text)
    i = 0
    n = len(text)
    line = 1
    while i < n:
        ch = text[i]
        if ch == "\n":
            line += 1
            i += 1
            continue
        if text.startswith("/-", i):
            block_open_lines.add(line)
            depth = 1
            j = i + 2
            out[i] = out[i + 1] = " "
            while j < n and depth > 0:
                if text.startswith("/-", j):
                    depth += 1
                    out[j] = out[j + 1] = " "
                    j += 2
                    continue
                if text.startswith("-/", j):
                    depth -= 1
                    out[j] = out[j + 1] = " "
                    j += 2
                    continue
                if text[j] == "\n":
                    line += 1
                else:
                    out[j] = " "
                j += 1
            i = j
            continue
        if text.startswith("--", i):
            j = i
            while j < n and text[j] != "\n":
                out[j] = " "
                j += 1
            i = j
            continue
        i += 1
    return "".join(out), block_open_lines


def indent_of(line):
    return len(line) - len(line.lstrip(" \t"))


def find_declaration(clean_lines, wanted):
    """Return (index, qualified_name, indent) of the declaration, or None.

    Both the bare name and the fully-qualified (namespace-prefixed) name are
    accepted, and both are compared for EQUALITY.
    """
    stack = []
    for idx, line in enumerate(clean_lines):
        ns = NAMESPACE_RE.match(line)
        if ns:
            stack.append(ns.group(1))
            continue
        endm = END_RE.match(line)
        if endm:
            if stack and stack[-1] == endm.group(1):
                stack.pop()
            continue
        m = DECL_RE.match(line)
        if not m:
            continue
        name = m.group("name")
        qualified = ".".join(stack + [name]) if stack else name
        if wanted == name or wanted == qualified:
            return idx, qualified, len(m.group("indent").expandtabs(2))
    return None


def body_end(clean_lines, raw_lines, block_open_lines, start, decl_indent):
    """First line index after `start` that begins a construct at an indentation
    <= the declaration's. EOF otherwise.

    A line on which a block comment opens counts as a construct boundary: a
    `/-- ... -/` doc comment introduces the declaration that follows it, and its
    indentation has to be read from the RAW line because the clean line has been
    blanked.
    """
    for idx in range(start + 1, len(clean_lines)):
        line = clean_lines[idx]
        opens_block = (idx + 1) in block_open_lines
        if opens_block:
            ind = indent_of(raw_lines[idx].expandtabs(2))
        else:
            if not line.strip() or not CONSTRUCT_RE.match(line):
                continue
            ind = indent_of(line.expandtabs(2))
        if ind <= decl_indent:
            return idx
    return len(clean_lines)


def main():
    argv = sys.argv[1:]
    if len(argv) != 2 or not argv[0] or not argv[1]:
        sys.stderr.write("usage: lean_sorry_check.py <lean-file> <declaration-id>\n")
        return 3
    path, wanted = argv
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except (IOError, OSError) as exc:
        sys.stderr.write("lean_sorry_check: cannot read %s (%s)\n" % (path, exc))
        return 3

    clean, block_open_lines = strip_comments(text)
    raw_lines = text.split("\n")
    clean_lines = clean.split("\n")

    found = find_declaration(clean_lines, wanted)
    if found is None:
        sys.stderr.write(
            "lean_sorry_check: declaration not found: %s in %s\n" % (wanted, path))
        return 2
    start, qualified, decl_indent = found
    end = body_end(clean_lines, raw_lines, block_open_lines, start, decl_indent)

    for idx in range(start, end):
        m = SORRY_RE.search(clean_lines[idx])
        if m:
            sys.stderr.write(
                "lean_sorry_check: %s::%s body contains %s at %s:%d\n"
                % (path, qualified, m.group(0), path, idx + 1))
            sys.stderr.write("    %s\n" % raw_lines[idx].strip())
            return 1

    print("lean-sorry-check OK: %s::%s (%d lines, no sorry/admit)"
          % (path, qualified, end - start))
    return 0


if __name__ == "__main__":
    sys.exit(main())
