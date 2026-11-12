#!/usr/bin/env python3
"""Simulate the actual mapped XC7 netlist against independent Python symbols."""
import argparse,json,subprocess,time
from pathlib import Path
from verify_hdl import frame_set,write_input,run_tool,assert_rows
from reference.integer_model import decode_integer
from host_decode import records_to_frames
ROOT=Path(__file__).resolve().parent
def main():
    p=argparse.ArgumentParser();p.add_argument('--iverilog',default='iverilog');p.add_argument('--vvp',default='vvp');p.add_argument('--base')
    p.add_argument('--cells',required=True,help='Yosys share/yosys/xilinx/cells_sim.v')
    p.add_argument('--lanes',type=int,choices=[1,8],default=8);a=p.parse_args()
    tag=f'L{a.lanes}_DC0_A0';out=ROOT/'results'/'post_synthesis'/tag;out.mkdir(parents=True,exist_ok=True)
    aa,bb=frame_set(293),frame_set(937)
    # Tail/reset boundaries plus a threshold ramp, impulses and a long random frame.
    indices=list(range(34))+[43,44,46,56];aa=[aa[i] for i in indices];bb=[bb[i] for i in indices]
    # Unrolled mapped logic is much slower in an event-driven gate simulator.
    # Keep all 34 boundary frames and representative 256-sample long patterns.
    # The full numerical/RTL suite remains unchanged.
    if a.lanes==8:
        aa=[(n,x[:256]) for n,x in aa];bb=[(n,x[:256]) for n,x in bb]
    inp=out/'input.txt';write_input(inp,aa,bb,a.lanes,813)
    exe=out/'sim.vvp';trace=out/'records.txt'
    mapped=ROOT/'results'/'synthesis'/tag/'mapped_netlist.v'
    cmd=[a.iverilog]+(['-B',a.base] if a.base else [])+['-g2012','-DMAPPED_NETLIST','-s','tb_analyzer',f'-Ptb_analyzer.LANES={a.lanes}','-o',str(exe),str(mapped),a.cells,str(ROOT/'tests/tb_analyzer.sv')]
    start=time.time();run_tool(cmd,out/'compile.log',timeout=240)
    stdout=run_tool([a.vvp,str(exe),f'+INPUT={inp}',f'+TRACE={trace}',f'+FRAMES={len(aa)}'],out/'simulation.log',timeout=300)
    if 'PASS' not in stdout:raise AssertionError(stdout)
    records=[int(l,16) for l in trace.read_text().splitlines()];actual=records_to_frames(records);symbols=0
    for channel,frames in enumerate([aa,bb]):
        for frame,(_,x) in enumerate(frames):
            g=decode_integer(x);expected=list(map(int,g['symbols']));symbols+=len(expected)
            assert_rows(actual.get((channel,frame)),expected,'post-synthesis symbols',tag)
    report=dict(configuration=tag,passed=True,technology='XC7 functional primitive simulation, no timing delays',
        channel_frames=2*len(aa),channel_samples_checked=sum(len(x) for _,x in aa+bb),
        symbols_checked=symbols,records=len(records),elapsed_seconds=round(time.time()-start,2),simulation=stdout.strip())
    (out/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
if __name__=='__main__':main()
