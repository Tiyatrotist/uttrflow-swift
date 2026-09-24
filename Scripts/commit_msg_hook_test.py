#!/usr/bin/env python3
"""Proves the commit-msg hook refuses a message for the reason it actually has."""

import importlib.util
import os
import re
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
HOOK = os.path.join(ROOT, ".githooks", "commit-msg")
BLAME = "text that must not be published"


def forbidden_sample():
    """A string matching a tier-1 pattern, built at run time so this file carries no such term."""
    spec = importlib.util.spec_from_file_location("audit", os.path.join(HERE, "disclosure_audit.py"))
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    for group in (audit.NAMES, audit.PHRASES):
        for pattern in group:
            candidate = re.sub(r"\\b|\(\?i\)|[\\^$]", "", pattern.pattern)
            candidate = candidate.replace("s+", " ").replace("[- ]", " ").replace("?", "")
            if pattern.search(candidate):
                return candidate
    return None


class CommitMessageHookTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="uttrflow-commit-msg-")

    def run_hook(self, text=None, name="COMMIT_EDITMSG"):
        """Runs the hook over a message file, or over one deliberately never written."""
        path = os.path.join(self.directory, name)
        if text is not None:
            with open(path, "w") as handle:
                handle.write(text)
        return subprocess.run(
            ["bash", HOOK, path], cwd=ROOT, capture_output=True, text=True
        )

    def test_a_plain_message_is_recorded(self):
        run = self.run_hook("Add a line\n\nA body as plain as the subject.\n")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_a_message_shaped_like_gits_own_flags_is_read_as_text(self):
        run = self.run_hook("Fix --not --remotes=origin handling\n\n--range -x --label z\n")
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_an_unreadable_file_is_not_blamed_on_the_message(self):
        run = self.run_hook(text=None, name="never-written")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn("Could not read the message file", run.stdout)
        self.assertNotIn(BLAME, run.stdout)

    def test_a_forbidden_term_is_still_refused(self):
        sample = forbidden_sample()
        if sample is None:
            self.skipTest("no tier-1 pattern could be turned back into a sample")
        run = self.run_hook(f"Subject line\n\n{sample}\n")
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
        self.assertIn(BLAME, run.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
