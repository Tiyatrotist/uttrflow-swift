#!/usr/bin/env python3
"""Proves the issue template audit catches every prompt that would publish forbidden content."""

import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIT = os.path.join(HERE, "issue_template_audit.py")


def run(audit_args, working=None):
    return subprocess.run(
        [sys.executable, AUDIT, *audit_args], cwd=working, capture_output=True, text=True
    )


class SelfTest(unittest.TestCase):
    """The audit's own fixtures prove its reasoning; they have to keep passing."""

    def test_self_test_passes(self):
        run = subprocess.run([sys.executable, AUDIT, "--self-test"], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("self-test passed", run.stdout)


class TreeTest(unittest.TestCase):
    """The repository's own templates must stay clean; a regression here means the bug returns."""

    REPO = os.path.dirname(HERE)

    def test_tree_passes(self):
        run = subprocess.run(
            [sys.executable, AUDIT], cwd=self.REPO, capture_output=True, text=True
        )
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("none invite content", run.stdout)


class ReasonTest(unittest.TestCase):
    """An invented bad template must be caught; the test runs the audit against a throwaway tree."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="uttrflow-template-test-")
        os.makedirs(os.path.join(self.tmp, ".github", "ISSUE_TEMPLATE"))
        self.addCleanup(self._cleanup)

    def _cleanup(self):
        import shutil

        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write(self, name, text):
        path = os.path.join(self.tmp, ".github", "ISSUE_TEMPLATE", name)
        with open(path, "w") as handle:
            handle.write(text)
        return path

    def test_inviting_phrase_is_refused(self):
        self._write(
            "feature_request.yml",
            "name: feature\nbody:\n"
            "  - type: textarea\n"
            "    id: alternatives\n"
            "    attributes:\n"
            "      label: What you do instead today\n"
            "      description: Including other apps.\n",
        )
        run = subprocess.run(
            [sys.executable, AUDIT], cwd=self.tmp, capture_output=True, text=True
        )
        self.assertEqual(run.returncode, 1, run.stdout)
        self.assertIn("invites product names", run.stderr)

    def test_workflow_field_without_warning_is_refused(self):
        self._write(
            "feature_request.yml",
            "name: feature\nbody:\n"
            "  - type: textarea\n"
            "    id: alternatives\n"
            "    attributes:\n"
            "      label: What you do instead today\n"
            "      description: A capability you reach for.\n",
        )
        run = subprocess.run(
            [sys.executable, AUDIT], cwd=self.tmp, capture_output=True, text=True
        )
        self.assertEqual(run.returncode, 1, run.stdout)
        self.assertIn("no publication warning", run.stderr)

    def test_passing_template_is_accepted(self):
        self._write(
            "feature_request.yml",
            "name: feature\nbody:\n"
            "  - type: markdown\n"
            "    attributes:\n"
            "      value: |\n"
            "        **Publication note.** What you write here is published.\n"
            "  - type: textarea\n"
            "    id: alternatives\n"
            "    attributes:\n"
            "      label: What you do today\n"
            "      description: The capability or workflow you reach for.\n",
        )
        run = subprocess.run(
            [sys.executable, AUDIT], cwd=self.tmp, capture_output=True, text=True
        )
        self.assertEqual(run.returncode, 0, run.stdout)
        self.assertIn("none invite content", run.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
