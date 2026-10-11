#!/usr/bin/env python3
"""Verify the integrity of a learning plan's learn/ and learn_es/ folders.

Checks performed:
  1. Required files exist in both language folders.
  2. Every section file in learn/ has a same-named counterpart in learn_es/.
  3. Question IDs match between each English section and its Spanish mirror.
  4. Every question ID has a corresponding answer in that folder's ANSWERS.md.
  5. Every term listed in a section's frontmatter appears in that folder's
     GLOSSARY.md.

Exit codes: 0 = clean, 1 = problems found, 2 = usage/IO error.

Usage:
    python3 scripts/check_learn.py [repo_root]
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

EN_DIR = "learn"
ES_DIR = "learn_es"
SECTION_FILE_PATTERN = re.compile(r"^(\d{2})-[a-z0-9-]+\.md$")
QUESTION_ID_PATTERN = re.compile(r"\bQ-(\d+\.\d+)\b")
ANSWER_ID_PATTERN = re.compile(r"\bA-(\d+\.\d+)\b")
GLOSSARY_HEADING_PATTERN = re.compile(r"^#{2,4}\s+(.+?)\s*$", re.MULTILINE)
FRONTMATTER_PATTERN = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
TERMS_LINE_PATTERN = re.compile(r"^terms:\s*\[(.*?)\]\s*$", re.MULTILINE)

REQUIRED_EN = ("00-PLAN.md", "ANSWERS.md", "GLOSSARY.md", "PROGRESS.md")
REQUIRED_ES = ("00-PLAN.md", "ANSWERS.md", "GLOSSARY.md")


@dataclass
class Report:
    """Collects problems found during the check."""

    problems: list[str] = field(default_factory=list)
    checked: int = 0

    def fail(self, message: str) -> None:
        self.problems.append(message)

    @property
    def ok(self) -> bool:
        return not self.problems


def read_text(path: Path) -> str:
    """Read a file, returning an empty string if it cannot be read."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"warning: could not read {path}: {exc}", file=sys.stderr)
        return ""


def section_files(folder: Path) -> dict[str, Path]:
    """Map section file name -> path for every NN-slug.md in the folder."""
    if not folder.is_dir():
        return {}
    return {
        entry.name: entry
        for entry in sorted(folder.iterdir())
        if entry.is_file() and SECTION_FILE_PATTERN.match(entry.name)
    }


def frontmatter_terms(content: str) -> list[str]:
    """Extract the `terms: [...]` list from a section file's frontmatter."""
    front = FRONTMATTER_PATTERN.match(content)
    if front is None:
        return []
    match = TERMS_LINE_PATTERN.search(front.group(1))
    if match is None:
        return []
    return [term.strip().strip("'\"") for term in match.group(1).split(",") if term.strip()]


def glossary_terms(content: str) -> set[str]:
    """Every heading in a glossary, lowercased for comparison."""
    return {heading.strip().lower() for heading in GLOSSARY_HEADING_PATTERN.findall(content)}


def check_required_files(root: Path, report: Report) -> None:
    for folder_name, required in ((EN_DIR, REQUIRED_EN), (ES_DIR, REQUIRED_ES)):
        folder = root / folder_name
        if not folder.is_dir():
            report.fail(f"missing folder: {folder_name}/")
            continue
        for name in required:
            if not (folder / name).is_file():
                report.fail(f"missing required file: {folder_name}/{name}")
    if not (root / "CLAUDE.md").is_file():
        report.fail("missing CLAUDE.md at repo root (agent contract)")


def check_parity(root: Path, report: Report) -> None:
    english = section_files(root / EN_DIR)
    spanish = section_files(root / ES_DIR)

    for name in english.keys() - spanish.keys():
        report.fail(f"no Spanish mirror for {EN_DIR}/{name}")
    for name in spanish.keys() - english.keys():
        report.fail(f"orphan Spanish section {ES_DIR}/{name} (no English original)")

    for name in sorted(english.keys() & spanish.keys()):
        report.checked += 1
        en_ids = set(QUESTION_ID_PATTERN.findall(read_text(english[name])))
        es_ids = set(QUESTION_ID_PATTERN.findall(read_text(spanish[name])))
        for missing in sorted(en_ids - es_ids):
            report.fail(f"{name}: Q-{missing} exists in {EN_DIR}/ but not in {ES_DIR}/")
        for extra in sorted(es_ids - en_ids):
            report.fail(f"{name}: Q-{extra} exists in {ES_DIR}/ but not in {EN_DIR}/")


def check_answers_and_glossary(root: Path, report: Report) -> None:
    for folder_name in (EN_DIR, ES_DIR):
        folder = root / folder_name
        sections = section_files(folder)
        if not sections:
            continue

        answers = set(ANSWER_ID_PATTERN.findall(read_text(folder / "ANSWERS.md")))
        glossary = glossary_terms(read_text(folder / "GLOSSARY.md"))

        for name, path in sections.items():
            content = read_text(path)

            for question_id in sorted(set(QUESTION_ID_PATTERN.findall(content))):
                if question_id not in answers:
                    report.fail(f"{folder_name}/{name}: Q-{question_id} has no answer in ANSWERS.md")

            for term in frontmatter_terms(content):
                if term.lower() not in glossary:
                    report.fail(f"{folder_name}/{name}: term '{term}' is not in GLOSSARY.md")


def main(argv: list[str]) -> int:
    root = Path(argv[1]).expanduser().resolve() if len(argv) > 1 else Path.cwd()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    report = Report()
    try:
        check_required_files(root, report)
        check_parity(root, report)
        check_answers_and_glossary(root, report)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if report.ok:
        print(f"OK — {report.checked} section pair(s) checked, no problems found.")
        return 0

    print(f"{len(report.problems)} problem(s) found:\n")
    for problem in report.problems:
        print(f"  - {problem}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
