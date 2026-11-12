#!/usr/bin/env python3
import argparse,json,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def main():
    p=argparse.ArgumentParser();p.add_argument('--iverilog',default='iverilog');p.add_argument('--vvp',default='vvp');p.add_argument('--base');a=p.parse_args()
    out=ROOT/'results'/'interfaces';out.mkdir(parents=True,exist_ok=True);results=[]
    for tb in ['tb_fifo','tb_protocol']:
        cmd=[a.iverilog]+(['-B',a.base] if a.base else [])+['-g2012','-s',tb,'-o',str(out/f'{tb}.vvp')]+[str(s) for s in sorted((ROOT/'rtl').glob('*.sv'))]+[str(ROOT/'tests'/f'{tb}.sv')]
        c=subprocess.run(cmd,capture_output=True,text=True);(out/f'{tb}_compile.log').write_text(c.stdout+c.stderr)
        if c.returncode:raise RuntimeError(c.stderr)
        r=subprocess.run([a.vvp,str(out/f'{tb}.vvp')],capture_output=True,text=True,timeout=120)
        (out/f'{tb}.log').write_text(r.stdout+r.stderr)
        if r.returncode or 'PASS' not in r.stdout:raise RuntimeError(r.stdout+r.stderr)
        results.append(dict(test=tb,passed=True,output=r.stdout.strip()));print(r.stdout,flush=True)
    r=subprocess.run(['python3','-m','unittest','discover','-s','tests','-p','test_*.py','-v'],cwd=ROOT,capture_output=True,text=True)
    (out/'python_tests.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise RuntimeError(r.stdout+r.stderr)
    results.append(dict(test='host_parser_unittest',passed=True,output=r.stderr.strip()))
    (out/'validation.json').write_text(json.dumps(dict(all_passed=True,tests=results),indent=2))
if __name__=='__main__':main()
