#!/usr/bin/env python3
"""Decode portable 128-bit host records; no Ethernet PCS/frame decoding implied."""
import argparse,csv,json
from pathlib import Path

def records_to_frames(records):
    frames={};closed=set();next_frame=[0,0]
    for record in records:
        if record < 0 or record >= 1<<128:raise ValueError('Record is not 128-bit')
        if record>>105:raise ValueError('Nonzero reserved header bits')
        count=(record>>64)&127;channel=(record>>71)&1
        last=(record>>72)&1;frame=(record>>73)&0xffffffff
        if count>32:raise ValueError('Symbol count exceeds 32')
        key=(channel,frame)
        if frame!=next_frame[channel]:raise ValueError('Frame order discontinuity')
        if key in closed:raise ValueError('Data after terminal record')
        symbols=frames.setdefault(key,[])
        if count==0 and not last:raise ValueError('Empty nonterminal record')
        if (record & ((1<<64)-1))>>(2*count):raise ValueError('Nonzero padding symbols')
        for i in range(count):
            code=(record>>(2*i))&3
            if code==2:raise ValueError('Illegal PAM3 symbol code 10')
            symbols.append(-1 if code==3 else code)
        if last:closed.add(key);next_frame[channel]=(frame+1)&0xffffffff
    if set(frames)!=closed:raise ValueError('Truncated capture: frame has no terminal record')
    return frames

def read_binary(path):
    data=Path(path).read_bytes()
    if len(data)%16:raise ValueError('Binary record file is not a multiple of 16 bytes')
    return [int.from_bytes(data[i:i+16],'little') for i in range(0,len(data),16)]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('input',help='Binary records, 16 little-endian bytes each')
    p.add_argument('--csv',default='decoded_symbols.csv')
    p.add_argument('--summary',default='decoded_summary.json')
    args=p.parse_args();frames=records_to_frames(read_binary(args.input))
    with open(args.csv,'w',newline='') as f:
        w=csv.writer(f);w.writerow(['channel','frame','ordinal','symbol'])
        for (channel,frame),symbols in sorted(frames.items()):
            for i,s in enumerate(symbols):w.writerow([channel,frame,i,s])
    Path(args.summary).write_text(json.dumps({'frames':[dict(channel=c,frame=f,symbols=len(s))
        for (c,f),s in sorted(frames.items())]},indent=2))
    print(f'Decoded {len(frames)} channel-frames, {sum(map(len,frames.values()))} symbols')

if __name__=='__main__':main()
