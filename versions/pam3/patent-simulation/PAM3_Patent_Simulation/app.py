#!/usr/bin/env python3
"""Optional local GUI. No internet, account, API key, or uploaded data needed."""
import argparse,json,math
from dataclasses import replace
from http.server import BaseHTTPRequestHandler,HTTPServer
from pathlib import Path
from urllib.parse import urlparse
from pam3.channel import ChannelConfig,generate_channel,evaluate
from run_simulation import execute

ROOT=Path(__file__).resolve().parent
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ["/","/PAM3_Results.html"]:
            self.send_error(404);return
        body=(ROOT/"PAM3_Results.html").read_bytes()
        self.send_response(200);self.send_header("Content-Type","text/html; charset=utf-8")
        self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
    def do_POST(self):
        if self.path!="/api/simulate":self.send_error(404);return
        origin=self.headers.get("Origin","")
        if origin and urlparse(origin).hostname not in ["localhost","127.0.0.1"]:
            self.send_error(403);return
        try:
            size=int(self.headers.get("Content-Length","0"))
            if size<1 or size>4096:raise ValueError("Invalid request length")
            p=json.loads(self.rfile.read(size))
            if not isinstance(p,dict):raise ValueError("Request must be a JSON object")
            n=int(p.get("symbols",1024));seed=int(p.get("seed",12345))
            if not 256<=n<=12000:raise ValueError("symbols must be 256..12000")
            values={k:float(p.get(k,d)) for k,d in [("snr_db",30),("gain",1),
                     ("dc_offset",0),("clock_ppm",0),("jitter_rms_samples",0)]}
            if any(not math.isfinite(v) for v in values.values()):raise ValueError("Finite values required")
            if not 0<=values["snr_db"]<=100 or not .1<=values["gain"]<=3:
                raise ValueError("SNR 0..100 dB, gain 0.1..3")
            if abs(values["dc_offset"])>100 or abs(values["clock_ppm"])>10000 or not 0<=values["jitter_rms_samples"]<=3:
                raise ValueError("offset +/-100, clock +/-10000 ppm, jitter 0..3")
            rows=[];traces={}
            for ch in ["master","slave"]:
                cfg=ChannelConfig(n_symbols=n,seed=seed+(7919 if ch=="slave" else 0),**values)
                signal=generate_channel(cfg)
                methods={}
                start,stop=384,min(len(signal["adc"]),2304)
                for method in ["patent_fixed_bypass","patent_literal_dc","inferred_adaptive_bypass","two_threshold_fixed_clock"]:
                    d=execute(signal,method);rows.append(dict(channel=ch,method=method,**evaluate(signal,d)))
                    keep=(d["points"]>=start)&(d["points"]<stop)
                    methods[method]=dict(levels=d["levels"][start:stop].tolist(),
                        raw=d.get("raw_levels",d["levels"])[start:stop].tolist(),
                        corrected=d.get("corrected",signal["adc"])[start:stop].tolist(),
                        points=d["points"][keep].tolist(),symbols=d["symbols"][keep].tolist())
                traces[ch]=dict(start=start,adc=signal["adc"][start:stop].tolist(),
                    expected=signal["expected_levels"][start:stop].tolist(),methods=methods)
            body=json.dumps(dict(parameters=p,metrics=rows,traces=traces),allow_nan=False).encode()
            self.send_response(200);self.send_header("Content-Type","application/json")
            self.send_header("Content-Length",str(len(body)));self.end_headers();self.wfile.write(body)
        except (ValueError,KeyError,TypeError,OverflowError,json.JSONDecodeError) as e:
            body=json.dumps({"error":str(e)}).encode()
            self.send_response(400);self.send_header("Content-Type","application/json");self.end_headers();self.wfile.write(body)

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--port",type=int,default=8765);a=p.parse_args()
    print(f"Open http://127.0.0.1:{a.port} in your browser. Ctrl+C to stop.",flush=True)
    HTTPServer(("127.0.0.1",a.port),Handler).serve_forever()
