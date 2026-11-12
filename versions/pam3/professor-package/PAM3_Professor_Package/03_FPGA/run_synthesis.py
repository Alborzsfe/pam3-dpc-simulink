#!/usr/bin/env python3
"""Reproducible Yosys XC7 mapping; this is NOT Vivado implementation/timing."""
import argparse,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def run(yosys,lanes,dc,adaptive):
    tag=f'L{lanes}_DC{dc}_A{adaptive}'
    out=ROOT/'results'/'synthesis'/tag;out.mkdir(parents=True,exist_ok=True)
    sources=' '.join('"'+str(s)+'"' for s in sorted((ROOT/'rtl').glob('*.sv')))
    script='\n'.join([
        'read_verilog -sv '+sources,
        f'chparam -set LANES {lanes} -set DC_ENABLE {dc} -set ADAPTIVE {adaptive} pam3_analyzer_core',
        # SAT-based resource sharing is optional, and scales poorly for the
        # eight chronologically dependent lanes. Skip that optimization only.
        'synth_xilinx -top pam3_analyzer_core -family xc7 -noiopad -noclkbuf -run begin:map_dsp',
        'techmap -map +/cmp2lut.v -map +/cmp2lcu.v -D LUT_WIDTH=6',
        'alumacc; opt; memory -nomap; opt_clean',
        'synth_xilinx -top pam3_analyzer_core -family xc7 -noiopad -noclkbuf -run map_memory:',
        'check -assert',
        'select -assert-none t:$dlatch t:$_DLATCH_* t:LDCE t:LDPE',
        'tee -o statistics.json stat -json',
        'write_verilog -noattr mapped_netlist.v',
        'write_edif mapped_netlist.edf'])+'\n'
    script_path=out/'synthesize.ys';script_path.write_text(script)
    started=time.time()
    with (out/'synthesis.log').open('w') as log:
        result=subprocess.run([yosys,'-T','-s',str(script_path)],cwd=out,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=900)
    if result.returncode:raise RuntimeError((out/'synthesis.log').read_text()[-6000:])
    stats=json.loads((out/'statistics.json').read_text())
    design=stats['design'];cells=design['num_cells_by_type']
    report=dict(configuration=tag,tool=subprocess.check_output([yosys,'-V'],text=True).strip(),
        family='Xilinx 7-series (XC7), generic mapping, no physical part selected',
        elapsed_seconds=round(time.time()-started,2),check_passed=True,inferred_latches=0,
        flow='synth_xilinx with optional SAT resource-sharing optimization omitted',
        cell_counts=cells,total_cells=design['num_cells'],
        LUT_cells=sum(v for k,v in cells.items() if k.startswith('LUT')),
        FF_cells=sum(v for k,v in cells.items() if k in ['FDRE','FDSE','FDCE','FDPE']),
        scope='Technology-mapped netlist only; no place/route, frequency, electrical I/O or board execution proof')
    (out/'summary.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--yosys',default='yosys');p.add_argument('--lanes',type=int,choices=[1,8],default=8)
    p.add_argument('--dc',type=int,choices=[0,1],default=0);p.add_argument('--adaptive',type=int,choices=[0,1],default=0)
    a=p.parse_args();run(a.yosys,a.lanes,a.dc,a.adaptive)
