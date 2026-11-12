"""Regenerate MATLAB fixtures from the independent offline Python oracle."""
from pathlib import Path
import sys, json, hashlib
import numpy as np
from scipy.io import savemat

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from python_reference.model import DecoderConfig, decode
from python_reference.integer_model import decode_integer
from python_reference.channel import ChannelConfig, generate_channel

def frame_set(seed):
    rng = np.random.default_rng(seed)
    frames = [('empty', np.array([], dtype=int))]
    for n in range(1, 34):
        frames.append((f'tail_{n}', rng.integers(0, 256, n)))
    for value in [0, 60, 80, 95, 127, 140, 160, 194, 255]:
        frames.append((f'constant_{value}', np.full(385, value)))
    frames += [('strict_thresholds', np.tile([0,80,81,95,96,139,140,141,159,160,161,255,255,0],90)),
               ('adc_ramps', np.tile(np.r_[np.arange(256),np.arange(255,-1,-1)],4)),
               ('long_runs', np.repeat([127,60,194,127,194,60,127],[36,750,24,1020,108,372,9])),
               ('width_1_2_3', np.tile([194]*12+[127]+[194]*13+[60]*2+[194]*13+[127]*3+[194]*12,40))]
    for n in [127,128,129,255,256,257,1023,1024,1025,4093]:
        frames.append((f'random_{n}', rng.integers(0,256,n)))
    for snr in [32,18,9]:
        symbols = rng.integers(-1,2,400); x = 127+67*np.repeat(symbols,12)
        for i in range(1,len(x)): x[i] = round(.7*x[i]+.3*x[i-1])
        x = x+rng.normal(0,67*10**(-snr/20),len(x))
        frames.append((f'pam3_snr_{snr}', np.clip(np.rint(x),0,255).astype(int)))
    return frames

def oracle(adc, dc, mode):
    cfg = DecoderConfig(dc_enabled=bool(dc),adaptive=mode!=0)
    if mode == 2 and len(adc):return decode(adc,cfg)
    return decode_integer(adc,cfg)

def packet(symbols,channel,last):
    payload=0
    for i,s in enumerate(symbols):payload|=(int(s)%4)<<(2*i)
    value=payload | (len(symbols)<<64) | (channel<<71) | (int(last)<<72)
    return value.to_bytes(16,'little')

def host_bytes(a,b):
    # A symbol at index q is emitted while processing position q+20.
    streams=[]
    for channel,adc in enumerate([a,b]):
        g=oracle(adc,0,0); events=[]; pending=[]
        for point,symbol in zip(g['points'],g['symbols']):
            pending.append(int(symbol))
            if len(pending)==32:
                # A final word occurring exactly at the terminal tick is last.
                last=int(point)==len(adc)-1
                events.append((int(point)+20,channel,packet(pending,channel,last)))
                pending=[]
        final_tick=len(adc)+19
        if not events or events[-1][0]!=final_tick:
            events.append((final_tick,channel,packet(pending,channel,True)))
        streams.extend(events)
    streams.sort(key=lambda v:(v[0],v[1]))
    return np.frombuffer(b''.join(v[2] for v in streams),dtype=np.uint8).copy()

def main():
    out=ROOT/'data';out.mkdir(exist_ok=True)
    cases=[]
    for channel,seed in enumerate([81871,66183]):
        for name,adc in frame_set(seed):
            for dc,mode in [(0,0),(1,0),(0,1),(1,1),(0,2)]:
                g=oracle(adc,dc,mode)
                c=dict(name=name,channel=channel,dc_enabled=dc,adaptive_mode=mode,
                       adc=np.asarray(adc,dtype=float).reshape(-1,1))
                for key in ['corrected','raw_levels','levels','points','symbols']:
                    c[key]=np.asarray(g[key],dtype=float).reshape(-1,1)
                c['thresholds']=np.asarray(g['thresholds'],dtype=float).reshape(-1,4)
                cases.append(c)
    savemat(out/'golden_cases.mat',{'cases':np.asarray(cases,dtype=object).reshape(-1,1)},do_compression=True)
    signals=[generate_channel(ChannelConfig(n_symbols=512,snr_db=30,seed=771+ch*7919,phase_samples=1.7+1.1*ch)) for ch in range(2)]
    n=max(len(x['adc']) for x in signals)
    demo={}
    for ch,label in enumerate(['master','slave']):
        demo['adc_'+label]=np.pad(signals[ch]['adc'],(0,n-len(signals[ch]['adc'])),mode='edge').astype(float).reshape(-1,1)
        demo['tx_'+label]=signals[ch]['tx'].astype(float).reshape(-1,1)
        demo['boundaries_'+label]=signals[ch]['boundaries'].reshape(-1,1)
    demo['snr_db']=30.0
    savemat(out/'demo_capture.mat',demo,do_compression=True)
    a=frame_set(81871)[-3][1];b=frame_set(66183)[-3][1]
    savemat(out/'host_golden.mat',dict(adc_master=a.reshape(-1,1),adc_slave=b.reshape(-1,1),expected_bytes=host_bytes(a,b).reshape(-1,1)),do_compression=True)
    summary=dict(reference='Independent offline Python runs/edges/candidate lists',
        captures=len(cases),real_sample_exposures=sum(len(c['adc']) for c in cases),
        expected_symbols=sum(len(c['symbols']) for c in cases),
        configurations=['fixed/DC-off','fixed/literal-DC','Q8/DC-off','Q8/literal-DC','float/DC-off'],
        rng_seeds=[81871,66183],matlab_executed=False,simulink_executed=False)
    (ROOT/'validation/fixture_manifest.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
