#!/usr/bin/env python3
"""Elaborate/lower every validated parameter combination; check netlist structure."""
import argparse,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def main():
    p=argparse.ArgumentParser();p.add_argument('--yosys',default='yosys');a=p.parse_args()
    out=ROOT/'results'/'structure';out.mkdir(parents=True,exist_ok=True);results=[]
    src=' '.join('"'+str(s)+'"' for s in sorted((ROOT/'rtl').glob('*.sv')))
    configs=[(lanes,dc,ad) for lanes in [1,8] for dc,ad in [(0,0),(1,0),(0,1),(1,1)]]
    for config in configs+[None]:
        top='pam3_analyzer_core' if config else 'pam3_capture_fifo'
        tag='capture_fifo' if not config else 'L%d_DC%d_A%d'%config
        script=['read_verilog -sv '+src]
        if config:script.append('chparam -set LANES %d -set DC_ENABLE %d -set ADAPTIVE %d pam3_analyzer_core'%config)
        script += ['hierarchy -check -top '+top,'proc','opt','memory_collect','opt_clean','check -assert',
            'select -assert-none t:$dlatch t:$_DLATCH_*',f'tee -o {tag}_statistics.json stat -json']
        path=out/f'{tag}.ys';path.write_text('\n'.join(script)+'\n');start=time.time()
        with (out/f'{tag}.log').open('w') as log:r=subprocess.run([a.yosys,'-T','-s',str(path)],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=300)
        if r.returncode:raise RuntimeError((out/f'{tag}.log').read_text()[-4000:])
        rec=dict(configuration=tag,passed=True,inferred_latches=0,elapsed_seconds=round(time.time()-start,2))
        results.append(rec);print('PASS',rec,flush=True)
    (out/'validation.json').write_text(json.dumps(dict(all_passed=True,scope='Elaboration, process lowering, optimization, connectivity and no-latch assertions. Not technology mapping or timing.',configurations=results),indent=2))
if __name__=='__main__':main()
