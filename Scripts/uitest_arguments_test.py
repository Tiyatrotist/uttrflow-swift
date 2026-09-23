#!/usr/bin/env python3
"""Proves the UI harness refuses a rounds argument it cannot honour, before it drives anything."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "UITests", "UITest.swift")

# The harness's exit codes. 4 is the usage refusal; 2 is "the app is not running", which is
# as far as an accepted argument gets on a machine with nothing installed.
USAGE = 4
NOT_RUNNING = 2

APP = "Uttrflow.app/Contents/MacOS/Uttrflow"


def app_is_running():
    return subprocess.run(["pgrep", "-f", APP], capture_output=True).returncode == 0


class RoundsArgumentTests(unittest.TestCase):
    """Drives the compiled harness, which needs neither the app nor Accessibility to refuse."""

    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.mkdtemp(prefix="uttrflow-uitest-arguments-")
        cls.binary = os.path.join(cls.directory, "uitest")
        # -Onone: this compiles the harness only to ask it about its arguments.
        built = subprocess.run(
            ["xcrun", "swiftc", "-Onone", HARNESS, "-o", cls.binary],
            capture_output=True,
            text=True,
        )
        if built.returncode != 0:
            raise AssertionError(f"the harness did not compile:\n{built.stderr}")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.directory, ignore_errors=True)

    def run_with(self, *arguments):
        return subprocess.run(
            [self.binary, *arguments], capture_output=True, text=True, timeout=120
        )

    def assert_refused(self, *arguments):
        """Refused by exit status, and told why in a line that names the argument and its domain."""
        finished = self.run_with(*arguments)
        self.assertEqual(finished.returncode, USAGE, finished.stderr)
        said = finished.stdout + finished.stderr
        self.assertIn("rounds", said)
        self.assertIn("usage:", said)

    def assert_accepted(self, *arguments):
        """Past the argument check and into the setup, which is where a real run begins."""
        if app_is_running():
            self.skipTest("Uttrflow is running; an accepted argument would drive the interface")
        finished = self.run_with(*arguments)
        self.assertEqual(finished.returncode, NOT_RUNNING, finished.stderr)
        self.assertNotIn("usage:", finished.stdout + finished.stderr)

    def test_no_argument_means_one_round(self):
        self.assert_accepted()

    def test_a_positive_count_is_accepted(self):
        self.assert_accepted("3")

    def test_zero_is_refused(self):
        self.assert_refused("0")

    def test_a_negative_count_is_refused(self):
        self.assert_refused("-1")

    def test_text_that_is_not_a_number_is_refused(self):
        self.assert_refused("all")

    def test_a_trailing_decimal_is_refused(self):
        self.assert_refused("2.5")

    def test_extra_arguments_are_refused(self):
        self.assert_refused("2", "3")


if __name__ == "__main__":
    unittest.main(verbosity=1)
