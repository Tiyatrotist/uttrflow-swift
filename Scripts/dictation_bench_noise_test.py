#!/usr/bin/env python3
"""Proves the synthetic bench mixes noise at the SNR its label claims. See #1266."""

import array
import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dictation_bench as bench  # noqa: E402

TOLERANCE_DB = 0.5


def sine_clip(n=73_568, freq=440, amplitude=10_000, rate=16_000):
    """A deterministic stand-in for speech, so the test does not depend on `say`."""
    return array.array(
        "h", [int(amplitude * math.sin(2 * math.pi * freq * i / rate)) for i in range(n)]
    )


def rms(samples):
    return math.sqrt(sum(x * x for x in samples) / len(samples))


class NoiseSnrTests(unittest.TestCase):
    def measured_snr_db(self, target_db, seed=1):
        signal = sine_clip()
        mixed = bench.noisy(target_db, seed)(signal)
        noise = array.array("h", (m - s for m, s in zip(mixed, signal)))
        return 20 * math.log10(rms(signal) / rms(noise))

    def test_the_20_db_variant_measures_close_to_20_db(self):
        measured = self.measured_snr_db(20)
        self.assertAlmostEqual(measured, 20, delta=TOLERANCE_DB)

    def test_the_10_db_variant_measures_close_to_10_db(self):
        measured = self.measured_snr_db(10)
        self.assertAlmostEqual(measured, 10, delta=TOLERANCE_DB)

    def test_neither_variant_clips_a_clean_sine_at_moderate_amplitude(self):
        signal = sine_clip()
        for target_db in (20, 10):
            mixed = bench.noisy(target_db, 1)(signal)
            self.assertTrue(all(-32768 <= x <= 32767 for x in mixed))


if __name__ == "__main__":
    unittest.main(verbosity=1)
