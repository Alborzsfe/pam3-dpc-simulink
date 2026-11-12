"""Structural checks only. Does not build or execute MATLAB/Simulink models."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
import xml.etree.ElementTree as ET
import numpy as np
from scipy.io import loadmat

root = Path(__file__).resolve().parents[1]
expected_sha = 'c637ed60cde46882b00b42aefcaf2d51796233b7814fdf6bbf72d947dcafd9a9'
source = root / 'source_model/DPC_POWER_RAHMAN_original.slx'
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected_sha
with zipfile.ZipFile(source) as archive:
    xml = ET.fromstring(archive.read('simulink/systems/system_root.xml'))
blocks = {b.get('Name'): b for b in xml.findall('Block')}
assert all(n in blocks for n in ('A\n\n', 'B', 'Controlled Voltage Source',
                                 'Three-Phase\nV-I Measurement', 'Subsystem', 'From', 'From1'))
measurement_id = blocks['Three-Phase\nV-I Measurement'].get('SID')
for phase, name in enumerate(('A\n\n', 'B', 'Controlled Voltage Source'), 1):
    source_id = blocks[name].get('SID')
    assert any(
        {p.get('Name'): p.text for p in line.findall('P')}.get('Src') == f'{source_id}#rconn:1'
        and {p.get('Name'): p.text for p in line.findall('P')}.get('Dst') == f'{measurement_id}#lconn:{phase}'
        for line in xml.findall('Line')
    ), 'The source insertion code must match the actual single physical connection.'
methods = ('conventional', 'binary_limit', 'proposed')
cases = ('normal', 'vnoise_1pct', 'vnoise_3pct', 'pqnoise_05', 'pqnoise_2', 'grid_distorted', 'combined')
for case in cases:
    for method in methods:
        for rate in (20, 200):
            name = f'DPCN_{case}_s104729_{method}_{rate}k'
            assert len(name) <= 63 and re.fullmatch(r'[A-Za-z]\w*', name)
new = loadmat(root / 'data/dpc3_noise_golden.mat', simplify_cells=True)
assert new['table_inputs'].shape == (648, 21)
assert new['gates'].shape == (648, 6) and new['audit'].shape == (648, 21)
assert set(map(tuple, new['table_inputs'][:, :2])) == {(p, q) for p in (-1, 0, 1) for q in (-1, 0, 1)}
assert set(new['table_inputs'][:, 2]) == set(range(1, 13))
for item in new['native']:
    assert item['input'].shape == (108, sum((1, 1, 1, 3, 3, 1, 1, 1, 1, 1, 2)))
    assert item['gates'].shape == (108, 6)
for name in ('numerical_report.mat', 'callback_report.mat', 'noise_numerical_report.mat', 'noise_analysis_report.mat'):
    report = loadmat(root / 'validation' / name, simplify_cells=True)['report']
    assert report['passed'] and not report['simulink_executed']
assert not list((root / 'validation').glob('native*.mat'))
assert not list((root / 'SEND_TO_PROFESSOR').glob('**/*.png'))
assert not list((root / 'SEND_TO_PROFESSOR').glob('**/*.csv'))
all_m = list(root.rglob('*.m'))
defined = {p.stem for p in all_m}
called = set()
variables = set()
for p in all_m:
    called.update(re.findall(r'\b((?:dpc3_|quality_|dpc_clean_)\w+)\s*\(', p.read_text()))
    variables.update(re.findall(r'\b(dpc3_\w+)\s*=', p.read_text()))
assert not (called - defined - variables), f'Missing helper functions: {called - defined - variables}'
attach = (root / 'matlab/dpc3_attach_disturbances.m').read_text()
assert "'Outputs','[3 1 1]'" in attach
assert "'OutputAfterFinalValue','Holding final value'" in attach
assert "'Interpolate','off'" in attach
assert "replace_input(model,[model '/Subsystem'],1,ports.v_feedback)" in attach
report = dict(passed=True, simulink_executed=False,
              source_sha256=expected_sha, matched_physical_source_connections=3,
              matlab_files=len(all_m), missing_custom_helpers=0,
              noisy_table_contexts=648, noisy_stream_samples=216,
              included_native_performance_results=False)
(root / 'validation/structure_report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
