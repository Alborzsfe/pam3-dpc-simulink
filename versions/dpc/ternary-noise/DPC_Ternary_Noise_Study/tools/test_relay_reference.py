"""Regression tests for the native R2024b threshold observations. No Simulink."""
import unittest
import numpy as np
from scipy.io import loadmat
from reference_and_fixtures import ROOT, binary


class NativeRelayReferenceTests(unittest.TestCase):
    def test_thresholds_and_adjacent_representable_values(self):
        for previous in (0, 1):
            self.assertEqual(binary(previous, 1.), 1)
            self.assertEqual(binary(previous, -1.), 0)
            self.assertEqual(binary(previous, np.nextafter(1., 0.)), previous)
            self.assertEqual(binary(previous, np.nextafter(-1., 0.)), previous)
            self.assertEqual(binary(previous, np.nextafter(1., np.inf)), 1)
            self.assertEqual(binary(previous, np.nextafter(-1., -np.inf)), 0)
            self.assertEqual(binary(previous, 0.), previous)

    def test_reported_mismatches_and_full_fixture_streams(self):
        data = loadmat(ROOT / 'data/dpc3_golden.mat', simplify_cells=True)
        observations = ((0, 43, 1., 1), (1, 39, -1., 0),
                        (1, 44, 1., 1), (1, 50, -1., 0))
        for item in data['native']:
            for channel in range(2):
                inclusive = strict = 0
                differences = []
                for index, error in enumerate(item['input'][:, channel]):
                    inclusive = binary(inclusive, error)
                    strict = 1 if error > 1 else (0 if error < -1 else strict)
                    self.assertEqual(inclusive, item['binary'][index, channel])
                    if inclusive != strict:
                        differences.append(index + 1)
                self.assertEqual(differences, [43] if channel == 0 else [39, 44, 50])
            for channel, sample, error, observed in observations:
                self.assertEqual(item['input'][sample - 1, channel], error)
                self.assertEqual(item['binary'][sample - 1, channel], observed)


if __name__ == '__main__':
    unittest.main()
