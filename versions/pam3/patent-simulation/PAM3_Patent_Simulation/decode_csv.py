#!/usr/bin/env python3
"""Decode measured unsigned 8-bit ADC data. No accuracy claim without TX reference."""
import argparse,csv
from pathlib import Path
import numpy as np
from pam3.model import DecoderConfig,decode

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("input",help="CSV with master and/or slave columns, ADC codes 0..255")
    p.add_argument("--out",default="decoded_adc")
    p.add_argument("--dc",action="store_true",help="Enable literal printed DC formula")
    p.add_argument("--adaptive",action="store_true",help="Enable inferred engineering update law")
    a=p.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    with open(a.input,newline="",encoding="utf-8-sig") as f:rows=list(csv.DictReader(f))
    if not rows:raise SystemExit("Empty CSV")
    channels=[ch for ch in ["master","slave"] if ch in rows[0]]
    if not channels:raise SystemExit("CSV header must contain master and/or slave")
    for ch in channels:
        data=np.array([float(r[ch]) for r in rows])
        if not np.all(np.isfinite(data)) or not np.all(data==np.rint(data)) or np.any((data<0)|(data>255)):
            raise SystemExit("ADC codes must be finite integers 0..255")
        d=decode(data.astype(np.uint8),DecoderConfig(dc_enabled=a.dc,adaptive=a.adaptive))
        np.savetxt(out/(ch+"_symbols.csv"),np.c_[d["points"],d["symbols"]],fmt="%d",delimiter=",",header="sample_index,symbol",comments="")
        np.savetxt(out/(ch+"_stages.csv"),np.c_[data,d["corrected"],d["raw_levels"],d["levels"]],fmt="%d",delimiter=",",header="adc,corrected,raw_level,filtered_level",comments="")
        print(ch,len(data),"samples ->",len(d["points"]),"symbols. SER not available without known TX.")
