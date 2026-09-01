"""Rough balance check for the H:AW Lua files.

Not a parser: it strips comments and string literals, then checks that block
keywords and brackets balance. Enough to catch a truncated edit before
deploying, which is otherwise a silent load failure.

Run from the repo root:  python tools/luacheck.py

Order matters, and getting it wrong produces false positives. An earlier
version stripped string literals before line comments, so a comment containing
an apostrophe ("the engine's own") opened a single-quote match that ran on
until the next apostrophe several lines later - swallowing real code, including
`end` keywords, and reporting an imbalance in a perfectly good file. Comments
are therefore removed per line, after the long-comment blocks and after quoted
strings on that same line.
"""
import glob
import io
import os
import re
import sys

ROOT = "SHAW/42/media/lua"

LONG_COMMENT = re.compile(r"--\[\[.*?\]\]", re.S)
LINE_COMMENT = re.compile(r"--[^\n]*")
DQ_STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
SQ_STRING = re.compile(r"'(?:[^'\\]|\\.)*'")

# `do` after for/while belongs to the same block, so it is not counted twice.
OPENERS = re.compile(r"\b(function|if|for|while)\b")
ENDS = re.compile(r"\bend\b")

failed = False
checked = 0

for path in sorted(glob.glob(os.path.join(ROOT, "**", "*.lua"), recursive=True)):
    text = io.open(path, encoding="utf-8").read()

    # Keep the line count stable so reported line numbers stay meaningful.
    text = LONG_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), text)

    depth = 0
    paren = 0
    brace = 0
    deepest_negative = None

    for number, raw in enumerate(text.split("\n"), 1):
        line = DQ_STRING.sub('""', raw)
        line = SQ_STRING.sub("''", line)
        line = LINE_COMMENT.sub("", line)

        depth += len(OPENERS.findall(line)) - len(ENDS.findall(line))
        paren += line.count("(") - line.count(")")
        brace += line.count("{") - line.count("}")

        if depth < 0 and deepest_negative is None:
            deepest_negative = number

    checked += 1

    if depth != 0 or paren != 0 or brace != 0:
        failed = True
        print("FAIL %s" % path)
        print("     block depth %+d, parens %+d, braces %+d" % (depth, paren, brace))
        if deepest_negative:
            print("     first unmatched `end` around line %d" % deepest_negative)

print("%d Lua files checked, %s"
      % (checked, "all balanced" if not failed else "SEE FAILURES ABOVE"))

sys.exit(1 if failed else 0)
