#!/usr/bin/env python3
"""Run the actual Monte Carlo and stress suite; no stored-result substitution."""
import argparse, csv, json, platform, sys, time
from dataclasses import replace
from pathlib import Path
import numpy as np
from pam3.channel import ChannelConfig, generate_channel, evaluate
from pam3.model import DecoderConfig, decode, naive_decode, config_dict

METHODS = {
    "patent_fixed_bypass": DecoderConfig(),
    "patent_literal_dc": DecoderConfig(dc_enabled=True),
    "inferred_adaptive_bypass": DecoderConfig(adaptive=True),
    "two_threshold_fixed_clock": DecoderConfig(),
}

def execute(signal, method):
    if method == "two_threshold_fixed_clock":
        return naive_decode(signal["adc"],METHODS[method])
    return decode(signal["adc"],METHODS[method])

def save_csv(path, rows):
    keys = list(dict.fromkeys(k for r in rows for k in r))
    with path.open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rows)

def run(out, n, repetitions):
    out.mkdir(parents=True,exist_ok=True)
    rows=[];traces={};start=time.time();symbol_exposures=0
    def case(suite,name,cfg,methods=tuple(METHODS),rep=0,save=False):
        nonlocal symbol_exposures
        for channel in ["master","slave"]:
            c=replace(cfg,seed=cfg.seed+(7919 if channel=="slave" else 0),
                      phase_samples=cfg.phase_samples+(1.1 if channel=="slave" else 0))
            s=generate_channel(c)
            symbol_exposures+=c.n_symbols
            d={}
            for method in methods:
                decoded=execute(s,method)
                metrics=evaluate(s,decoded)
                rows.append(dict(suite=suite,case=name,rep=rep,channel=channel,
                                 method=method,seed=c.seed,snr_db=c.snr_db,
                                 gain=c.gain,dc_offset=c.dc_offset,clock_ppm=c.clock_ppm,
                                 pattern=c.pattern,**metrics))
                if save:
                    d[method]={k:v for k,v in decoded.items() if isinstance(v,np.ndarray)}
            if save:
                traces[name+"_"+channel] = dict(signal=s,decoders=d)
        print(f"Completed {suite}/{name}/rep{rep}",flush=True)
    for snr in [10,14,18,22,26,30,40]:
        for rep in range(repetitions):
            case("snr",f"SNR_{snr}",ChannelConfig(n_symbols=n,snr_db=snr,
                 seed=11405248+rep*1009+int(snr)*101),rep=rep,
                 save=rep==0 and snr in [10,18,30])
    stress={
        "ideal":dict(snr_db=float("inf"),rise_tau_samples=0,phase_samples=0),
        "offset_plus25":dict(dc_offset=25),
        "offset_minus25":dict(dc_offset=-25),
        "gain_065":dict(gain=0.65),
        "gain_135":dict(gain=1.35),
        "dc_step_plus30":dict(dc_step=30),
        "gain_step_minus035":dict(gain_step=-0.35),
        "clock_plus1000ppm":dict(clock_ppm=1000),
        "clock_minus1000ppm":dict(clock_ppm=-1000),
        "jitter_08samples":dict(jitter_rms_samples=0.8),
        "echo_025":dict(echo_fraction=0.25),
        "coupler_leakage_015":dict(leakage_fraction=0.15),
        "impulses":dict(impulse_probability=0.002),
        "slow_edges":dict(rise_tau_samples=3.0),
        "long_runs_clock_drift":dict(pattern="long_runs",clock_ppm=1000),
        "only_minus_zero":dict(pattern="two_levels"),
        "alternating":dict(pattern="alternating"),
    }
    for j,(name,kwargs) in enumerate(stress.items()):
        case("stress",name,ChannelConfig(n_symbols=n,seed=92001+j*101,**kwargs),save=True)
    for gain in [0.6,0.8,1.0,1.2,1.4]:
        for offset in [-40,-20,0,20,40]:
            case("gain_offset",f"g{gain}_dc{offset}",ChannelConfig(n_symbols=n//2,
                 snr_db=30,gain=gain,dc_offset=offset,seed=22001),
                 methods=("patent_fixed_bypass","inferred_adaptive_bypass"))
    # Receiver initial phase is swept independently of TX phase, no oracle lock.
    phase_rows=[]
    for phase in np.arange(0,12,0.5):
        s=generate_channel(ChannelConfig(n_symbols=n//2,snr_db=40,phase_samples=float(phase),seed=55001))
        for method in ["patent_fixed_bypass","two_threshold_fixed_clock"]:
            phase_rows.append(dict(phase_samples=float(phase),method=method,**evaluate(s,execute(s,method))))
    save_csv(out/"phase_sweep.csv",phase_rows)
    # Sensitivity of the missing DC guard constant, held out from method tuning.
    dc_rows=[]
    s=generate_channel(ChannelConfig(n_symbols=n//2,snr_db=40,seed=77001))
    for gate in [60,80,95,110]:
        for anchor in [60,80,95]:
            cfg=DecoderConfig(dc_enabled=True,dc_min_gate=gate,dc_anchor=anchor)
            d=decode(s["adc"],cfg)
            dc_rows.append(dict(dc_min_gate=gate,dc_anchor=anchor,
                interpretation="literal_anchor" if anchor==95 else "changed_anchor_engineering_variant",
                active_fraction=float(np.mean(d["dc_active"])),**evaluate(s,d)))
    save_csv(out/"dc_sensitivity.csv",dc_rows)
    save_csv(out/"all_runs.csv",rows)
    summary=[]
    groups={}
    for row in rows:
        key=(row["suite"],row["case"],row["method"])
        groups.setdefault(key,[]).append(row)
    for (suite,name,method),group in groups.items():
        nn=sum(r["n_evaluated"] for r in group);ee=sum(r["errors"] for r in group)
        rates=[r["ser_total"] for r in group]
        z=1.959963984540054;rate=ee/nn;den=1+z*z/nn
        center=(rate+z*z/(2*nn))/den
        half=z*np.sqrt(rate*(1-rate)/nn+z*z/(4*nn*nn))/den
        summary.append(dict(suite=suite,case=name,method=method,n=nn,errors=ee,
            ser=rate,ci_low=max(0,center-half),ci_high=min(1,center+half),
            run_min=min(rates),run_max=max(rates),run_sd=float(np.std(rates,ddof=1)),
            missing=sum(r["missing"] for r in group),extra=sum(r["extra_outputs"] for r in group),
            amplitude_errors_single=sum(r["amplitude_errors_single"] for r in group),
            clipping_mean=float(np.mean([r["clipping_fraction"] for r in group])),
            timing_rms_ui=float(np.mean([r["timing_rms_ui"] for r in group if r["timing_rms_ui"] is not None])),
            **{k:group[0][k] for k in ["snr_db","gain","dc_offset","clock_ppm"]}))
    save_csv(out/"summary.csv",summary)
    # Complete ADC stimulus and stage traces retained for selected examples.
    trace_dir=out/"traces";trace_dir.mkdir(exist_ok=True)
    for key,trace in traces.items():
        arrays={"adc":trace["signal"]["adc"],"tx":trace["signal"]["tx"],
                "boundaries":trace["signal"]["boundaries"],"ideal":trace["signal"]["ideal"]}
        for method,d in trace["decoders"].items():
            arrays.update({method+"__"+k:v for k,v in d.items()})
        target=trace_dir/(key+".npz")
        temporary=trace_dir/(key+".tmp.npz")
        np.savez_compressed(temporary,**arrays)
        temporary.replace(target)
    meta=dict(patent="US11405248B2",date="2026-10-04",python=sys.version,
         platform=platform.platform(),numpy=np.__version__,n_symbols=n,
         snr_repetitions=repetitions,channels=2,generated_symbol_exposures=symbol_exposures,
         evaluated_method_runs=len(rows),elapsed_seconds=round(time.time()-start,3),
         decoder_configs={k:config_dict(v) for k,v in METHODS.items()},
         hardware_status="Functional Python simulation. HDL validation is reported separately.",
         confidence_note="Wilson intervals describe pooled observed symbol errors; burst correlation invalidates an independent-binomial interpretation. Independent-run min/max and SD are also provided.")
    (out/"metadata.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
    # JSON is standards compliant: no Infinity, NaN, or numpy scalar leaks.
    def clean(obj):
        if isinstance(obj,float) and not np.isfinite(obj): return None
        if isinstance(obj,dict):return {k:clean(v) for k,v in obj.items()}
        if isinstance(obj,list):return [clean(v) for v in obj]
        return obj
    (out/"summary.json").write_text(json.dumps(clean(summary),indent=2,allow_nan=False),encoding="utf-8")
    print(json.dumps(meta,indent=2),flush=True)

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--out",default="results")
    p.add_argument("--symbols",type=int,default=4096);p.add_argument("--repetitions",type=int,default=5)
    a=p.parse_args()
    if a.symbols<256 or a.repetitions<1:p.error("symbols >=256 and repetitions >=1 required")
    run(Path(a.out),a.symbols,a.repetitions)
