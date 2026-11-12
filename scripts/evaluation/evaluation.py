"""Shared code of the evaluation scripts: log parsing, CSV I/O, suite config, and tables."""

import csv
import math
import re
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

DIR_SCRIPT = Path(__file__).resolve().parent
DIR_LOGS = DIR_SCRIPT.parent.parent / "logs"
PATH_CONFIG = DIR_SCRIPT / "suites.toml"

FIELDS = ["section", "test", "result", "time"]
META = "meta"

RE_SECTION = re.compile(r"^== (\S+) \((.*)\)$")
RE_TEST = re.compile(r"^\[\s*\d+/\d+\] (.+?) \.\.\. (.*)$")
RE_OUTCOME = re.compile(r"^(.+?)  ([0-9.]+)s  \([0-9.]+s\)$")


def warn(text):
    print(f"warning: {text}", file=sys.stderr)


# Logs to CSV


def parse_log(path):
    """Returns the rows of the tests a log ran, skipping excluded ones."""
    rows = []
    section, root = "", ""
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if m := RE_SECTION.match(line):
            section, root = m.groups()
            continue
        if not (m := RE_TEST.match(line)):
            continue
        name, rest = m.groups()
        if rest.strip() == "exclude":
            continue
        if not (m := RE_OUTCOME.match(rest)):
            warn(f"{path.name}:{lineno}: no outcome for {name}")
            continue
        outcome, time = m.groups()
        # A mismatch reads `<result>, expected <outcome>`
        result = outcome.partition(", expected ")[0]
        test = f"{root}/{name}" if root else name
        rows.append({"section": section, "test": test, "result": result, "time": time})
    return rows


def write_csv(path, rows):
    with path.open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def convert_log(path):
    """Writes `<log>.csv` beside a log and returns its rows."""
    rows = parse_log(path)
    write_csv(path.with_suffix(".csv"), rows)
    return rows


def read_csv(path):
    with path.open(newline="") as file:
        return list(csv.DictReader(file))


# Suites


@dataclass
class Cell:
    """Union of the test results of one suite under one column."""
    results: dict  # test -> (result, seconds)
    missing: list  # sources without a log

    def __len__(self):
        return len(self.results)


def load_config(path=PATH_CONFIG):
    with path.open("rb") as file:
        return tomllib.load(file)


def load_source(dir_logs, source):
    """Returns the rows of a `<log>` or `<log>#<section>` source, or None without its log.

    Converts the log first when its CSV is missing or older than the log.
    """
    name, _, section = source.partition("#")
    path_log = dir_logs / f"{name}.log"
    path_csv = path_log.with_suffix(".csv")
    if path_log.exists() and (not path_csv.exists()
                              or path_csv.stat().st_mtime < path_log.stat().st_mtime):
        print(f"converting {path_log}", file=sys.stderr)
        rows = convert_log(path_log)
    elif path_csv.exists():
        rows = read_csv(path_csv)
    else:
        return None
    if section:
        rows = [row for row in rows if row["section"] == section]
    return rows


def load_cell(dir_logs, sources):
    results, missing = {}, []
    for source in sources:
        rows = load_source(dir_logs, source)
        if rows is None:
            missing.append(source)
            continue
        for row in rows:
            if row["test"] in results:
                warn(f"{source}: {row['test']} already has a result; keeping the last")
            results[row["test"]] = (row["result"], float(row["time"]))
    return Cell(results, missing)


def load_suites(dir_logs, config):
    """Returns `(suite, {column: Cell})` per suite row of the config."""
    loaded = []
    for suite in config["suites"]:
        cells = {key: load_cell(dir_logs, suite.get(key, [])) for key in config["columns"]}
        loaded.append((suite, cells))
    return loaded


def towers(config):
    return [key for key in config["columns"] if key != META]


def total(config, cells):
    """Number of tests any tower ran in the suite."""
    tests = set()
    for key in towers(config):
        tests |= cells[key].results.keys()
    return len(tests)


def notes_incomplete(config, loaded, keys):
    """Footnotes on cells with fewer tests than their suite total."""
    notes = []
    for suite, cells in loaded:
        n_total = total(config, cells)
        for key in keys:
            cell = cells[key]
            if len(cell) == 0 or len(cell) >= n_total:
                continue
            text = f"* {suite['name']} {config['columns'][key]}: {len(cell):,} of {n_total:,} tests"
            if cell.missing:
                text += f" (no log for {', '.join(cell.missing)})"
            notes.append(text)
    if any(len(cells[key]) == 0 for _, cells in loaded for key in keys):
        notes.append("- no log for the cell")
    return notes


def is_incomplete(config, cells, key):
    return 0 < len(cells[key]) < total(config, cells)


# Statistics


def count(cell, labels):
    return sum(1 for result, _ in cell.results.values() if result in labels)


def median_time(cell):
    """Median seconds per test, a timeout counting as infinite."""
    times = sorted(math.inf if result == "timeout" else secs
                   for result, secs in cell.results.values())
    if not times:
        return None
    mid = len(times) // 2
    if len(times) % 2:
        return times[mid]
    return (times[mid - 1] + times[mid]) / 2


# Rendering


def render(headers, rows, rules=()):
    """Renders a text table; `headers` are `(group, name)` pairs, merged over equal groups.

    `rules` lists the row indices preceded by a horizontal rule.
    """
    width = [max(len(name), *(len(row[i]) for row in rows)) for i, (_, name) in enumerate(headers)]
    # Widen the last column of a group too narrow for its title
    spans = []
    for i, (group, _) in enumerate(headers):
        if spans and group and spans[-1][0] == group:
            spans[-1][2] = i
        else:
            spans.append([group, i, i])
    for group, start, end in spans:
        inner = sum(width[start:end + 1]) + 3 * (end - start)
        if len(group) > inner:
            width[end] += len(group) - inner

    def line(cells):
        return " | ".join(cell.rjust(w) if i else cell.ljust(w)
                          for i, (cell, w) in enumerate(zip(cells, width)))

    rule = "-+-".join("-" * w for w in width)
    out = []
    if any(group for group, _ in headers):
        out.append(" | ".join(group.center(sum(width[s:e + 1]) + 3 * (e - s))
                              for group, s, e in spans))
    out += [line([name for _, name in headers]), rule]
    for i, row in enumerate(rows):
        if i in rules:
            out.append(rule)
        out.append(line(row))
    return "\n".join(out)


def rules(config):
    """Row indices of suites marked `rule = true`."""
    return [i for i, suite in enumerate(config["suites"]) if suite.get("rule")]
