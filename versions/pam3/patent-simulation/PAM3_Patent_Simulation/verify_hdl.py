#!/usr/bin/env python3
"""Independently execute SystemVerilog and compare every stage/sample/point/value."""
import argparse,json,os,shutil,subprocess
from pathlib import Path
from dataclasses import replace
import numpy as np
from pam3.channel import ChannelConfig,generate_channel
from pam3.model import DecoderConfig,decode

ROOT=Path(__file__).resolve().parent

def run(iverilog="iverilog",vvp="vvp",base=None):
    out=ROOT/"results"/"hdl";out.mkdir(parents=True,exist_ok=True)
    cmd=[iverilog]
    if base:cmd += ["-B",base]
    cmd += ["-g2012","-s","tb_dual","-o",str(out/"sim.vvp"),
            str(ROOT/"rtl/pam3_frontend.sv"),str(ROOT/"rtl/pam3_reference.sv"),str(ROOT/"rtl/tb_dual.sv")]
    compiled=subprocess.run(cmd,text=True,capture_output=True)
    (out/"compile.log").write_text(compiled.stdout+compiled.stderr)
    if compiled.returncode:raise RuntimeError(compiled.stderr)
    records=[]
    cases=[("clean",{}),("noise10",dict(snr_db=10)),("drift",dict(clock_ppm=1000)),
           ("impulses",dict(impulse_probability=.006)),("step",dict(dc_step=25)),
           ("long_runs",dict(pattern="long_runs",clock_ppm=1000))]
    for case,kwargs in cases:
        aa=generate_channel(ChannelConfig(n_symbols=768,seed=31001,**kwargs))
        bb=generate_channel(ChannelConfig(n_symbols=768,seed=39001,phase_samples=2.8,**kwargs))
        n=min(len(aa["adc"]),len(bb["adc"]))
        inp=out/(case+"_input.txt")
        np.savetxt(inp,np.c_[aa["adc"][:n],bb["adc"][:n]],fmt="%d")
        for dc in [False,True]:
            tag=case+("_dc" if dc else "_bypass")
            a,b=decode(aa["adc"][:n],DecoderConfig(dc_enabled=dc)),decode(bb["adc"][:n],DecoderConfig(dc_enabled=dc))
            stages=out/(tag+"_stages.txt")
            np.savetxt(stages,np.c_[a["corrected"],a["raw_levels"],b["corrected"],b["raw_levels"]],fmt="%d")
            syma,symb=out/(tag+"_a.txt"),out/(tag+"_b.txt")
            for dest,d in [(syma,a),(symb,b)]:
                with dest.open("w") as f:
                    f.write(str(len(d["points"]))+"\n")
                    np.savetxt(f,np.c_[d["points"],d["symbols"]],fmt="%d")
            args=[vvp,str(out/"sim.vvp"),f"+N={n}",f"+DC={int(dc)}",f"+INPUT={inp}",
                  f"+STAGES={stages}",f"+SYMA={syma}",f"+SYMB={symb}"]
            if case=="clean" and not dc:args.append(f"+VCD={out/'dual_channel.vcd'}")
            result=subprocess.run(args,text=True,capture_output=True,timeout=60)
            (out/(tag+".log")).write_text(result.stdout+result.stderr)
            ok=result.returncode==0 and "PASS" in result.stdout
            record=dict(case=case,dc_enabled=dc,samples_per_channel=n,
                        symbols_a=len(a["points"]),symbols_b=len(b["points"]),passed=ok,
                        output=result.stdout.strip())
            records.append(record);print(record,flush=True)
            if not ok:raise RuntimeError("HDL mismatch: "+result.stdout+result.stderr)
    (out/"validation.json").write_text(json.dumps(dict(simulator="Icarus Verilog 12.0",
       cases=records,all_passed=all(x["passed"] for x in records),
       total_channel_samples_checked=sum(2*x["samples_per_channel"] for x in records),
       scope="Complete frame-based HDL reference plus synthesizable DC/slope front end. Inferred adaptive Python variant excluded. No Vivado or board execution, synthesis, resource, or 800 MS/s claim."),indent=2))

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--iverilog",default="iverilog");p.add_argument("--vvp",default="vvp");p.add_argument("--base")
    a=p.parse_args();run(a.iverilog,a.vvp,a.base)
