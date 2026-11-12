#!/usr/bin/env python3
"""Package reproducible sources/evidence, excluding regenerable bulky scratch."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def included(p):
    rel=p.relative_to(ROOT)
    if '__pycache__' in rel.parts or 'build' in rel.parts or 'quick' in rel.parts:return False
    if p.suffix in ['.vvp','.pyc','.vcd']:return False
    if p.name=='SHA256SUMS.txt':return False
    if rel.parts[0]=='results' and p.suffix=='.txt' and p.name!='example_adc_input.txt':return False
    return True
def main():
    metadata=dict(patent='US11405248B2',delivery='Portable streaming digital reconstruction',created='2026-10-04',
        implemented='Paired deserialized 8-bit ADC -> PAM3 levels/points/symbols -> 128-bit host records',
        files_requiring_external_tools='Icarus for RTL, Yosys for mapping, Vivado for optional OOC flow',
        physical_limit='No board-specific ADC PHY/CDC/coupler/DVGA/USB/PCS/bitstream or frequency measurement',
        validation_files=['results/verification/validation.json','results/interfaces/validation.json','results/structure/validation.json',
            'results/synthesis/L1_DC0_A0/summary.json','results/synthesis/L8_DC0_A0/summary.json',
            'results/post_synthesis/L1_DC0_A0/validation.json','results/post_synthesis/L8_DC0_A0/validation.json'])
    (ROOT/'DELIVERY_MANIFEST.json').write_text(json.dumps(metadata,indent=2))
    files=[p for p in sorted(ROOT.rglob('*')) if p.is_file() and included(p)]
    digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    (ROOT/'SHA256SUMS.txt').write_text('\n'.join(digest(p)+'  '+p.relative_to(ROOT).as_posix() for p in files)+'\n')
    files.append(ROOT/'SHA256SUMS.txt')
    target=ROOT.parent/'PAM3_FPGA_Implementation.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=8) as z:
        for p in files:z.write(p,ROOT.name+'/'+p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(target) as z:
        bad=z.testzip();assert bad is None,bad
        lines=z.read(ROOT.name+'/SHA256SUMS.txt').decode().splitlines()
        for line in lines:
            expected,name=line.split('  ',1)
            assert hashlib.sha256(z.read(ROOT.name+'/'+name)).hexdigest()==expected,name
    print(json.dumps(dict(zip=str(target),files=len(files),size_bytes=target.stat().st_size,integrity='PASS'),indent=2))
if __name__=='__main__':main()
