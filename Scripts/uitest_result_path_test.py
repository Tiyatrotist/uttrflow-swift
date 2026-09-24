#!/usr/bin/env python3
"""Proves a second `make uitest` can reach the runner without a stale result bundle in the way.

Drives Scripts/uitest_result_path.sh directly, which needs no Xcode project, no app bundle and
no windowing session — the thing it does is filesystem-only, ahead of the real xcodebuild call.
"""

import os
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "uitest_result_path.sh")


class ResultBundlePathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="uttrflow-uitest-result-")
        self.addCleanup(self.tmp.cleanup)
        self.path = os.path.join(self.tmp.name, "uitest.xcresult")

    def run_script(self):
        return subprocess.run(
            [SCRIPT, self.path], capture_output=True, text=True, timeout=30
        )

    def test_a_path_with_nothing_there_is_returned_unchanged(self):
        finished = self.run_script()
        self.assertEqual(finished.returncode, 0, finished.stderr)
        self.assertEqual(finished.stdout.strip(), self.path)
        self.assertFalse(os.path.exists(self.path))

    def test_an_existing_bundle_is_moved_aside_not_deleted(self):
        os.mkdir(self.path)
        with open(os.path.join(self.path, "marker"), "w") as f:
            f.write("the first run's result")

        finished = self.run_script()

        self.assertEqual(finished.returncode, 0, finished.stderr)
        # The path handed back is the same one xcodebuild is told to write to next.
        self.assertEqual(finished.stdout.strip(), self.path)
        self.assertFalse(os.path.exists(self.path), "the old bundle is in the way of the new one")

        archived = [
            name
            for name in os.listdir(self.tmp.name)
            if name != "uitest.xcresult" and name.startswith("uitest-")
        ]
        self.assertEqual(len(archived), 1, archived)
        with open(os.path.join(self.tmp.name, archived[0], "marker")) as f:
            self.assertEqual(f.read(), "the first run's result")

    def test_two_consecutive_runs_both_reach_a_usable_destination(self):
        """The exact scenario in the issue: `make uitest` twice in a row."""
        os.mkdir(self.path)
        first = self.run_script()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertFalse(os.path.exists(self.path))

        # A second real run would write a fresh bundle at the same path before testing again.
        os.mkdir(self.path)
        second = self.run_script()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(second.stdout.strip(), self.path)
        self.assertFalse(os.path.exists(self.path))

        # Both prior results survive, under distinct names.
        archived = [name for name in os.listdir(self.tmp.name) if name != "uitest.xcresult"]
        self.assertEqual(len(archived), 2, archived)

    def test_missing_argument_is_refused(self):
        finished = subprocess.run([SCRIPT], capture_output=True, text=True, timeout=30)
        self.assertNotEqual(finished.returncode, 0)
        self.assertIn("usage:", finished.stdout + finished.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
