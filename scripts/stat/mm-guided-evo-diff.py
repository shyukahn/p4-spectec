#!/usr/bin/env python3
"""Per-commit +/- line counts ignoring comments, blank lines and whitespace.

Usage: mm-guided-evo-diff.py [BASE] [HEAD]   (default: main mm-guided-evo-then)

For every commit in BASE..HEAD and every file it touches:
  1. take the file before (commit^) and after (commit) via `git show`
  2. strip comments  (.watsup: `;;` to end of line;
                      .rs: `//...` and nested `/* */`, string/char literals kept)
  3. drop lines that are empty after stripping
  4. `git diff --no-index -w --numstat` the two cleaned versions
"""
import os
import re
import subprocess
import sys
import tempfile


REPO = os.path.dirname(os.path.abspath(__file__))  # run git in this script's repo


def git(*args, check=True):
    return subprocess.run(["git", *args], capture_output=True, check=check, cwd=REPO).stdout


def strip_watsup(src: str) -> str:
    # `;;` never appears inside a string literal in this spec, so a plain cut is safe.
    return "\n".join(line.split(";;", 1)[0] for line in src.splitlines())


def strip_rust(src: str) -> str:
    out, i, n, depth = [], 0, len(src), 0
    while i < n:
        c = src[i]
        if depth:  # inside /* */ (Rust block comments nest)
            if src.startswith("/*", i):
                depth += 1; i += 2
            elif src.startswith("*/", i):
                depth -= 1; i += 2
            else:
                if c == "\n":
                    out.append(c)  # keep line structure
                i += 1
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            depth = 1; i += 2
            continue
        m = re.match(r'b?r(#*)"', src[i:i + 300])
        if m and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == "_")):  # raw string
            end = src.find('"' + m.group(1), i + m.end())
            end = n if end < 0 else end + 1 + len(m.group(1))
            out.append(src[i:end]); i = end
            continue
        if c == '"':  # normal string
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1]); i = j + 1
            continue
        if c == "'":  # char literal (vs. lifetime 'a)
            m = re.match(r"'(\\.[^']*|[^\\'])'", src[i:i + 12])
            if m:
                out.append(m.group(0)); i += m.end()
                continue
        out.append(c); i += 1
    return "".join(out)


STRIPPERS = {".watsup": strip_watsup, ".rs": strip_rust}


def clean(src: str, path: str) -> str:
    strip = STRIPPERS.get(os.path.splitext(path)[1], lambda s: s)
    lines = [l.strip() for l in strip(src).splitlines()]
    return "\n".join(l for l in lines if l) + "\n"


def blob(rev: str, path: str) -> str:
    return git("show", f"{rev}:{path}", check=False).decode("utf-8", "replace")


def file_stat(commit: str, old: str, new: str, tmp: str):
    a, b = os.path.join(tmp, "a"), os.path.join(tmp, "b")
    with open(a, "w") as f:
        f.write(clean(blob(commit + "^", old), old) if old else "")
    with open(b, "w") as f:
        f.write(clean(blob(commit, new), new) if new else "")
    out = git("diff", "--no-index", "-w", "--numstat", a, b, check=False).decode()
    if not out.strip():
        return 0, 0
    add, dele, _ = out.split("\t", 2)
    return int(add), int(dele)


def main():
    base, head = (sys.argv[1:] + ["main", "mm-guided-evo-then"][len(sys.argv) - 1:])[:2]
    commits = git("rev-list", "--reverse", f"{base}..{head}").decode().split()
    tot_a = tot_d = 0
    with tempfile.TemporaryDirectory() as tmp:
        for c in commits:
            subject = git("log", "-1", "--format=%h %s", c).decode().strip()
            print(f"\n== {subject}")
            ca = cd = 0
            # -M: follow renames; -z: robust parsing
            raw = git("diff", "--name-status", "-M", "-z", f"{c}^", c).decode().split("\0")
            k = 0
            while k < len(raw) and raw[k]:
                status = raw[k]
                if status[0] in "RC":
                    old, new = raw[k + 1], raw[k + 2]; k += 3
                else:
                    p = raw[k + 1]; k += 2
                    old = None if status == "A" else p
                    new = None if status == "D" else p
                a, d = file_stat(c, old, new, tmp)
                ca += a; cd += d
                print(f"  {a:>5} {d:>5}  {new or old}")
            print(f"  {'+' + str(ca):>5} {'-' + str(cd):>5}  (total)")
            tot_a += ca; tot_d += cd
    print(f"\n== ALL {len(commits)} commits: +{tot_a} -{tot_d}")


if __name__ == "__main__":
    main()
