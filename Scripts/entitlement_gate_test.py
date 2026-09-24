#!/usr/bin/env python3
"""Tests the entitlement gate used by bundle.sh and notarise.sh."""

import os
import plistlib
import subprocess
import sys
import unittest


HERE = os.path.dirname(os.path.abspath(__file__))
GATE = os.path.join(HERE, "entitlement_gate.py")
AUDIO_KEY = "com.apple.security.device.audio-input"
DEBUG_KEY = "com.apple.security.get-task-allow"


class EntitlementGateTests(unittest.TestCase):
    def run_gate(self, mode, key, entitlements):
        return subprocess.run(
            [sys.executable, GATE, mode, key],
            input=plistlib.dumps(entitlements) if entitlements is not None else b"",
            capture_output=True,
        )

    def test_require_true_accepts_only_boolean_true(self):
        run = self.run_gate("require-true", AUDIO_KEY, {AUDIO_KEY: True})
        self.assertEqual(run.returncode, 0, run.stderr)

    def test_require_true_rejects_false(self):
        run = self.run_gate("require-true", AUDIO_KEY, {AUDIO_KEY: False})
        self.assertEqual(run.returncode, 1)
        self.assertIn(b"not Boolean true", run.stderr)

    def test_require_true_rejects_missing_key(self):
        run = self.run_gate("require-true", AUDIO_KEY, {})
        self.assertEqual(run.returncode, 1)
        self.assertIn(b"missing", run.stderr)

    def test_require_true_rejects_empty_entitlements(self):
        run = self.run_gate("require-true", AUDIO_KEY, None)
        self.assertEqual(run.returncode, 1)
        self.assertIn(b"missing", run.stderr)

    def test_require_true_rejects_malformed_plist(self):
        run = subprocess.run(
            [sys.executable, GATE, "require-true", AUDIO_KEY],
            input=b"not a plist",
            capture_output=True,
        )
        self.assertEqual(run.returncode, 1)
        self.assertIn(b"could not parse", run.stderr)

    def test_forbid_true_rejects_only_boolean_true(self):
        run = self.run_gate("forbid-true", DEBUG_KEY, {DEBUG_KEY: True})
        self.assertEqual(run.returncode, 1)
        self.assertIn(b"Boolean true", run.stderr)

    def test_forbid_true_accepts_false_and_absent(self):
        for entitlements in [{DEBUG_KEY: False}, {}, None]:
            with self.subTest(entitlements=entitlements):
                run = self.run_gate("forbid-true", DEBUG_KEY, entitlements)
                self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=1)
