#!/usr/bin/env python3
"""Proves tier-2 counts every occurrence on a line, not just the first match per pattern."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import disclosure_audit  # noqa: E402


class HitsUnitTests(unittest.TestCase):
    """hits() itself, isolated from the file-walking and the ratchet around it."""

    def test_two_matches_of_one_pattern_on_one_line_both_count(self):
        found = list(disclosure_audit.hits("marker marker", [re.compile("marker")]))
        self.assertEqual(len(found), 2)

    def test_a_single_match_still_counts_once(self):
        found = list(disclosure_audit.hits("one marker here", [re.compile("marker")]))
        self.assertEqual(len(found), 1)

    def test_matches_of_different_patterns_on_one_line_all_count(self):
        patterns = [re.compile("marker"), re.compile("beacon")]
        found = list(disclosure_audit.hits("marker and beacon", patterns))
        self.assertEqual(len(found), 2)

    def test_matches_on_different_lines_each_count(self):
        found = list(disclosure_audit.hits("marker\nmarker", [re.compile("marker")]))
        self.assertEqual([number for number, _, _ in found], [1, 2])


class Workspace:
    """A throwaway tree carrying disclosure_audit.py, padded past its 100-file tripwire.

    TIER2 is swapped for one harmless pattern before the audit runs, so the fixture needs
    no real disclosure vocabulary — this file stays clean under the very gate it tests.
    """

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="uttrflow-disclosure-hits-")
        os.makedirs(os.path.join(self.root, "Scripts"))
        shutil.copy(
            os.path.join(HERE, "disclosure_audit.py"),
            os.path.join(self.root, "Scripts", "disclosure_audit.py"),
        )
        subprocess.run(["git", "init", "--quiet"], cwd=self.root, check=True)
        for index in range(105):
            self.write(f"Docs/filler-{index}.md", "Ordinary prose about dictation.\n")

    def write(self, relative, text):
        path = os.path.join(self.root, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(text)

    def record(self, files):
        with open(os.path.join(self.root, "Scripts", "disclosure_baseline.json"), "w") as handle:
            json.dump({"total": sum(files.values()), "files": files}, handle)

    def run(self, tier2_pattern):
        # Written outside the workspace tree, so the harness's own source — which names
        # the test pattern — is never itself a file the audit it drives would scan.
        if getattr(self, "harness_path", None):
            os.unlink(self.harness_path)
        harness = tempfile.NamedTemporaryFile(
            prefix="uttrflow-disclosure-harness-", suffix=".py", delete=False
        )
        self.harness_path = harness.name
        with harness:
            harness.write(
                (
                    "import re, sys\n"
                    "sys.path.insert(0, 'Scripts')\n"
                    "import disclosure_audit\n"
                    f"disclosure_audit.TIER2 = [re.compile({tier2_pattern!r})]\n"
                    "sys.exit(disclosure_audit.main())\n"
                ).encode()
            )
        return subprocess.run(
            [sys.executable, self.harness_path], cwd=self.root, capture_output=True, text=True
        )

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)
        if getattr(self, "harness_path", None):
            os.unlink(self.harness_path)
            self.harness_path = None


class BaselineRegressionTests(unittest.TestCase):
    """The acceptance case: a second same-line match must be visible to the ratchet."""

    def setUp(self):
        self.workspace = Workspace()
        self.addCleanup(self.workspace.close)

    def test_a_second_same_line_match_is_rejected(self):
        self.workspace.write("Docs/note.md", "one marker here\n")
        self.workspace.record({"Docs/note.md": 1})
        run = self.workspace.run("marker")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

        self.workspace.write("Docs/note.md", "one marker marker here\n")
        run = self.workspace.run("marker")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn("Docs/note.md: 2 occurrences, was 1", run.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
