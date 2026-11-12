#!/usr/bin/env python3
"""Run actual RTL, comparing all intermediate samples and final host records."""
import argparse,hashlib,json,os,re,shutil,subprocess,time
from pathlib import Path
import numpy as np
from reference.model import DecoderConfig,decode
from reference.integer_model import decode_integer
from host_decode import records_to_frames

ROOT=Path(__file__).resolve().parent

def frame_set(seed):
    rng=np.random.default_rng(seed)
    frames=[('empty',np.array([],dtype=int))]
    for n in range(1,34):frames.append((f'tail_{n}',rng.integers(0,256,n)))
    for value in [0,60,80,95,127,140,160,194,255]:
        frames.append((f'constant_{value}',np.full(385,value)))
    frames += [('strict_thresholds',np.tile([0,80,81,95,96,139,140,141,159,160,161,255,255,0],90)),
               ('adc_ramps',np.tile(np.r_[np.arange(256),np.arange(255,-1,-1)],4)),
               ('long_runs',np.repeat([127,60,194,127,194,60,127],[36,750,24,1020,108,372,9])),
               ('width_1_2_3',np.tile([194]*12+[127]+[194]*13+[60]*2+[194]*13+[127]*3+[194]*12,40))]
    for n in [127,128,129,255,256,257,1023,1024,1025,4093]:
        frames.append((f'random_{n}',rng.integers(0,256,n)))
    for snr in [32,18,9]:
        symbols=rng.integers(-1,2,400);x=127+67*np.repeat(symbols,12)
        for i in range(1,len(x)):x[i]=round(.7*x[i]+.3*x[i-1])
        x=x+rng.normal(0,67*10**(-snr/20),len(x))
        frames.append((f'pam3_snr_{snr}',np.clip(np.rint(x),0,255).astype(int)))
    return frames

def write_input(path,a,b,lanes,seed):
    rng=np.random.default_rng(seed)
    with path.open('w') as f:
        for (_,x),(_,y) in zip(a,b):
            assert len(x)==len(y)
            if not len(x):f.write('0 1 0'+(' 0' if b is not a else '')+'\n')
            i=0
            while i<len(x):
                n=min(lanes,len(x)-i)
                # Every fifth beat uses a partial vector, even away from the tail.
                if lanes>1 and rng.integers(5)==0:n=int(rng.integers(1,n+1))
                xa=sum(int(v)<<(8*j) for j,v in enumerate(x[i:i+n]))
                yb=sum(int(v)<<(8*j) for j,v in enumerate(y[i:i+n]))
                f.write(f'{n} {int(i+n==len(x))} {xa:x}'+(f' {yb:x}' if b is not a else '')+'\n');i+=n

def run_tool(cmd,log,timeout=240):
    result=subprocess.run(cmd,capture_output=True,text=True,timeout=timeout)
    log.write_text(result.stdout+result.stderr)
    if result.returncode:raise RuntimeError(f'{log.name}: {result.stdout[-2000:]} {result.stderr[-2000:]}')
    return result.stdout

def assert_rows(actual,expected,stage,tag):
    if actual!=expected:
        first=next((i for i,(a,b) in enumerate(zip(actual,expected)) if a!=b),min(len(actual),len(expected)))
        raise AssertionError(f'{tag} {stage}: counts {len(actual)}/{len(expected)}, first={first}, actual={actual[first:first+2]}, expected={expected[first:first+2]}')

def run(iv='iverilog',vvp='vvp',base=None,quick=False):
    out=ROOT/'results'/'verification';out.mkdir(parents=True,exist_ok=True)
    aa,bb=frame_set(81871),frame_set(66183)
    if quick:aa,bb=aa[:36],bb[:36]
    summary=[];start=time.time()
    sources=list(sorted((ROOT/'rtl').glob('*.sv')))
    for lanes in [1,8]:
        for dc,adaptive in [(0,0),(1,0),(0,1),(1,1)]:
            cfg=DecoderConfig(dc_enabled=bool(dc),adaptive=bool(adaptive))
            tag=f'L{lanes}_DC{dc}_A{adaptive}'
            gold_a=[decode_integer(x,cfg) for _,x in aa]
            gold_b=[decode_integer(x,cfg) for _,x in bb]
            # Separate floating-model fixed implementation must also agree.
            if not adaptive:
                for (_,x),g in zip(aa,gold_a):
                    if len(x):
                        d=decode(x,cfg)
                        for k in ['corrected','raw_levels','levels','points','symbols']:
                            if not np.array_equal(d[k],g[k]):raise AssertionError(f'Fixed references differ: {k}')
            core_input=out/f'{tag}_core_input.txt';write_input(core_input,aa,aa,lanes,131)
            dual_input=out/f'{tag}_dual_input.txt';write_input(dual_input,aa,bb,lanes,223)
            expected={'R':[],'F':[],'O':[],'E':[]}
            for f,g in enumerate(gold_a):
                expected['R'] += [[f,i,int(c),int(v)] for i,(c,v) in enumerate(zip(g['corrected'],g['raw_levels']))]
                expected['F'] += [[f,i,int(v)] for i,v in enumerate(g['levels'])]
                expected['O'] += [[f,int(p),int(v)] for p,v in zip(g['points'],g['symbols'])]
                expected['E'].append([f])
            rec={'configuration':tag,'lanes':lanes,'dc_enabled':bool(dc),'adaptive_q8':bool(adaptive),
                 'frames_per_channel':len(aa),'samples_per_channel':sum(len(x) for _,x in aa)}
            for kind,tb,inp in [('core','tb_stream',core_input),('analyzer','tb_analyzer',dual_input)]:
                exe=out/f'{tag}_{kind}.vvp';trace=out/f'{tag}_{kind}_trace.txt'
                cmd=[iv]+(['-B',base] if base else [])+['-g2012','-s',tb,f'-P{tb}.LANES={lanes}',f'-P{tb}.DC={dc}',f'-P{tb}.ADAPT={adaptive}','-o',str(exe)]+[str(s) for s in sources]+[str(ROOT/'tests'/f'{tb}.sv')]
                run_tool(cmd,out/f'{tag}_{kind}_compile.log')
                stdout=run_tool([vvp,str(exe),f'+INPUT={inp}',f'+TRACE={trace}',f'+FRAMES={len(aa)}'],out/f'{tag}_{kind}.log')
                if 'PASS' not in stdout:raise AssertionError(stdout)
                metrics={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',stdout)}
                rec[kind]=dict(passed=True,**metrics)
                if kind=='core':
                    actual={k:[] for k in expected}
                    for line in trace.read_text().splitlines():
                        parts=line.split();actual[parts[0]].append([int(v) for v in parts[1:]])
                    for k in expected:assert_rows(actual[k],expected[k],k,tag)
                    rec['core']['symbols_checked']=len(expected['O'])
                else:
                    records=[int(l,16) for l in trace.read_text().splitlines()]
                    frames=records_to_frames(records)
                    for channel,golds in enumerate([gold_a,gold_b]):
                        for frame,g in enumerate(golds):
                            assert_rows(frames.get((channel,frame)),list(map(int,g['symbols'])),'host symbols',tag)
                    rec['analyzer']['symbols_checked']=sum(len(g['symbols']) for g in gold_a+gold_b)
                    if tag=='L8_DC0_A0':
                        (ROOT/'results'/'example_host_records.bin').write_bytes(b''.join(r.to_bytes(16,'little') for r in records))
                        # Deliver the original input paired with this example capture.
                        shutil.copyfile(dual_input,ROOT/'results'/'example_adc_input.txt')
                print(f"PASS {tag} {kind}: {rec[kind]}",flush=True)
            summary.append(rec)
    report=dict(all_passed=True,simulator='Icarus Verilog 12.0',reference='Independent offline Python edge/sampling plus Q8 causal front end',
        elapsed_seconds=round(time.time()-start,2),configurations=summary,
        core_sample_checks=sum(r['samples_per_channel'] for r in summary),
        analyzer_channel_sample_checks=sum(2*r['samples_per_channel'] for r in summary),
        total_symbols_checked=sum(r['core']['symbols_checked']+r['analyzer']['symbols_checked'] for r in summary),
        total_channel_frames=sum(3*r['frames_per_channel'] for r in summary),
        stimulus_frames=[dict(name=n,samples=len(x)) for n,x in aa])
    (out/'validation.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k not in ['configurations','stimulus_frames']},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--iverilog',default=os.environ.get('IVERILOG','iverilog'))
    p.add_argument('--vvp',default=os.environ.get('VVP','vvp'));p.add_argument('--base',default=os.environ.get('IVERILOG_BASE'))
    p.add_argument('--quick',action='store_true');a=p.parse_args();run(a.iverilog,a.vvp,a.base,a.quick)
