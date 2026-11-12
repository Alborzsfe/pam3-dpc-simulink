from pathlib import Path
import csv,json,html
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
OUT=Path(__file__).resolve().parents[1]
S=OUT/'02_Simulation';F=OUT/'03_FPGA';V=OUT/'01_Results';A=V/'assets'
A.mkdir(parents=True,exist_ok=True)
def write(path,s):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(s,encoding='utf-8')
with (S/'results/all_runs.csv').open() as f: rows=list(csv.DictReader(f))
def aggregate(suite,case,method):
    rr=[r for r in rows if r['suite']==suite and r['case']==case and r['method']==method]
    n=sum(int(r['n_evaluated']) for r in rr)
    keys=['errors','missing','duplicated_symbols','extra_outputs','amplitude_errors_single']
    a={k:sum(int(r[k]) for r in rr) for k in keys}
    return dict(n=n,runs=len(rr),pct=100*a['errors']/n,**a)
fixed='patent_fixed_bypass';adaptive='inferred_adaptive_bypass';dc='patent_literal_dc';baseline='two_threshold_fixed_clock'
noise={x:aggregate('snr',f'SNR_{x}',fixed) for x in [10,14,18,22,26,30,40]}
dc30=aggregate('snr','SNR_30',dc)
stress={c:{m:aggregate('stress',c,m) for m in [fixed,adaptive,baseline,dc]} for c in ['gain_step_minus035','offset_plus25','offset_minus25','slow_edges']}
val=json.loads((F/'results/verification/validation.json').read_text())
syn=[json.loads((F/f'results/synthesis/L{l}_DC0_A0/summary.json').read_text()) for l in [1,8]]
post=[json.loads((F/f'results/post_synthesis/L{l}_DC0_A0/validation.json').read_text()) for l in [1,8]]
assert val['all_passed'] and val['total_symbols_checked']==73206
assert noise[30]['errors']==0 and noise[18]['errors']==224 and noise[10]['errors']==8775
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.labelcolor':'#334155','axes.edgecolor':'#cbd5e1','xtick.color':'#64748b','ytick.color':'#64748b','grid.color':'#e2e8f0','grid.alpha':.8,'savefig.facecolor':'white'})
blue='#2563eb';teal='#0f766e';orange='#b45309';red='#b91c1c';gray='#64748b'
def save(fig,n):fig.savefig(A/n,dpi=160,bbox_inches='tight');plt.close(fig)

z=np.load(S/'results/traces/SNR_30_master.npz');lo,hi=480,660;t=np.arange(lo,hi)
fig,axs=plt.subplots(3,1,figsize=(9.5,5.3),sharex=True,gridspec_kw={'height_ratios':[1.5,1,1]})
axs[0].plot(t,z['adc'][lo:hi],color=blue,lw=1.5,label='8-bit ADC')
for q in [80,95,140,160]:axs[0].axhline(q,color=gray,ls='--',lw=.6,alpha=.6)
axs[0].set_ylabel('ADC code');axs[0].set_ylim(30,225);axs[0].legend(loc='upper right',frameon=False)
axs[1].step(t,z[fixed+'__raw_levels'][lo:hi],where='post',color='#94a3b8',lw=1.1,label='Raw levels')
axs[1].step(t,z[fixed+'__levels'][lo:hi],where='post',color=teal,lw=1.7,label='After spike filter')
axs[1].set_ylabel('PAM3 level');axs[1].set_yticks([-1,0,1]);axs[1].set_ylim(-1.4,1.4);axs[1].legend(loc='upper right',frameon=False,ncol=2,fontsize=8)
idx=np.searchsorted(z['boundaries'],t,side='right')-1;expected=z['tx'][np.clip(idx,0,len(z['tx'])-1)]
axs[2].step(t,expected,where='post',color=gray,lw=1.1,label='Transmitted symbol')
p=z[fixed+'__points'];mask=(p>=lo)&(p<hi);p=p[mask];sym=z[fixed+'__symbols'][mask]
axs[2].scatter(p,sym,color=blue,s=35,zorder=3,label='Receiver sampling point')
for point in p:axs[2].axvline(point,color=blue,lw=.5,alpha=.18)
axs[2].set_ylabel('Output symbol');axs[2].set_yticks([-1,0,1]);axs[2].set_ylim(-1.4,1.4);axs[2].set_xlabel('ADC sample index (1.25 ns per sample, nominal)')
axs[2].legend(loc='upper right',frameon=False,ncol=2,fontsize=8)
for ax in axs:ax.grid(axis='y');ax.set_xlim(lo,hi-1)
fig.tight_layout(h_pad=1.5);save(fig,'signal_decode.png')

fig,ax=plt.subplots(figsize=(8.5,4.3))
for method,color,label in [(fixed,blue,'Patent reconstruction / fixed, DC off'),(adaptive,teal,'Inferred adaptive / DC off'),(baseline,gray,'Two-threshold baseline / fixed clock')]:
    xx=list(noise);yy=[aggregate('snr',f'SNR_{x}',method)['pct'] for x in xx]
    ax.plot(xx,yy,'o-',color=color,label=label,lw=1.6,ms=5)
ax.set_xlabel('SNR (dB) — larger means less noise');ax.set_ylabel('Total symbol error (%)');ax.set_ylim(bottom=-.5);ax.grid();ax.legend(frameon=False,fontsize=9)
fig.tight_layout();save(fig,'noise_test.png')

z=np.load(S/'results/traces/gain_step_minus035_master.npz');th=z[adaptive+'__thresholds'];n=len(th);x=np.arange(n);step=n//2
fig,ax=plt.subplots(figsize=(8.4,4.05))
for j,color,label in [(0,blue,'Plus'),(1,teal,'Minus'),(2,orange,'Zero Plus'),(3,gray,'Zero Minus')]:
    ax.plot(x[::24],th[::24,j],color=color,lw=1.3,label=label)
ax.axvline(step,color=red,ls='--',lw=1.2);ax.text(step+600,170,'Gain changes\n1.00 → 0.65',color=red,fontsize=9)
ax.set_ylim(65,180);ax.set_xlabel('ADC sample index');ax.set_ylabel('Threshold (ADC code)');ax.grid();ax.legend(ncol=4,frameon=False,loc='lower left')
fig.tight_layout();save(fig,'adaptive_thresholds.png')

fig,axs=plt.subplots(1,2,figsize=(8.5,3.7))
for ax,key,title,color in [(axs[0],'LUT_cells','Logic resources (LUT)',blue),(axs[1],'FF_cells','Registers (flip-flops)',teal)]:
    values=[s[key] for s in syn];bars=ax.bar(['1 sample/clock','8 samples/clock'],values,color=[gray,color],width=.55)
    for b,v in zip(bars,values):ax.text(b.get_x()+b.get_width()/2,v+max(values)*.035,f'{v:,}',ha='center',fontsize=12,fontweight='bold')
    ax.set_ylim(0,max(values)*1.23);ax.set_title(title,loc='left',fontsize=11,pad=15);ax.grid(axis='y');ax.set_axisbelow(True)
fig.tight_layout(w_pad=3);save(fig,'fpga_resources.png')

def esc(x):return html.escape(str(x))
def stat(label,value,note='',tone=''):
    return f'<div class="stat {tone}"><small>{label}</small><strong>{value}</strong><span>{note}</span></div>'
def table(headers,body):
    return '<table><thead><tr>'+''.join(f'<th>{h}</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join(f'<td>{c}</td>' for c in row)+'</tr>' for row in body)+'</tbody></table>'
def card(title,body,sub=''):
    return f'<article class="card"><h3>{title}</h3>'+ (f'<p class="sub">{sub}</p>' if sub else '')+body+'</article>'
def note(text,kind=''):return f'<div class="note {kind}">{text}</div>'
def img(n):return f'<img class="plot" src="assets/{n}">'
e18=noise[18]
data=[]
data.append(dict(id='signal',title='From ADC samples to PAM3 symbols',subtitle='A real saved trace from the simulation • Master channel • SNR 30 dB',stats=stat('ADC boundary','8-bit / 800 MS/s','Nominal sampling model')+stat('Receiver settings','140 / 95 / 160 / 80','Fixed thresholds · DC bypass')+stat('Shown window',f'{len(p)} output symbols',f'Samples {lo}–{hi-1} · one recorded run'),body='<div class="grid signal">'+card('Signal, decoded levels and chosen sampling points',img('signal_decode.png'),'Dots mark the samples actually selected by the receiver.')+card('What the code does',table(['Stage','Operation'],[['1 · DC','Bypassed in this view'],['2 · Level','Slope + four thresholds'],['3 · Spike','Isolated runs ≤2 samples'],['4 · Edges','Must events + edge filters'],['5 · Timing','12-sample step + resync'],['6 · Output','Read filtered level']])+note('The transmitter trace is used for evaluation only. Its labels and timing are not inputs to the receiver.')+'<div class="code">pam3/model.py<br>rtl/pam3_stream_core.sv</div>')+'</div>'+note('Source: SNR_30_master.npz · Python behavioural channel, not a measured cable.')))

body=card('Noise sweep',img('noise_test.png'),'Five seeds × two channels; 40,560 evaluated symbols per SNR and method.')
tbody=[[f'{k} dB',f'{noise[k]["errors"]:,} / {noise[k]["n"]:,}',f'{noise[k]["pct"]:.3f}%'] for k in [30,18,10]]
side=card('Fixed receiver · DC off',table(['SNR','Errors / evaluated','Rate'],tbody)+note('A symbol succeeds only if its interval contains exactly one output, with the correct value.')+table(['At 18 dB','Failed intervals'],[['Wrong value','86'],['Missing output','1'],['Repeated outputs','137'],['Total','224']]))
data.append(dict(id='noise',title='How noise changes the decoding result',subtitle='Performance against the known transmitted symbols • recorded Monte Carlo runs',stats=stat('30 dB','0 / 40,560','No error observed in this test')+stat('18 dB','0.552% error','224 failed symbol intervals')+stat('10 dB','21.635% error','8,775 failed symbol intervals'),body='<div class="grid">'+body+side+'</div>'+note('Metric: 100 × failed symbol intervals / evaluated intervals. First 32 and last 8 symbols excluded. Baseline and adaptive results are shown on the same scale; no universal winner is assumed.')))

labels={'gain_step_minus035':'Gain step 1 → 0.65','offset_plus25':'DC offset +25 codes','offset_minus25':'DC offset −25 codes','slow_edges':'Slow signal edges'}
tb=[[labels[c]]+[f'{stress[c][m]["pct"]:.3f}%' for m in [fixed,adaptive,baseline]] for c in stress]
g=stress['gain_step_minus035']
data.append(dict(id='adapt',title='Threshold tracking — and a DC ambiguity',subtitle='The adaptive update is an engineering reconstruction; the patent does not disclose its exact equation.',stats=stat('Gain-step test · fixed',f'{g[fixed]["pct"]:.3f}% error','552 / 8,112 evaluated symbols')+stat('Gain-step test · adaptive',f'{g[adaptive]["pct"]:.3f}% error','11 / 8,112 evaluated symbols')+stat('Literal DC · 30 dB',f'{dc30["pct"]:.3f}% error','26,487 / 40,560 · documented limitation','warn'),body='<div class="grid">'+card('Four thresholds follow a change in amplitude',img('adaptive_thresholds.png'),'Saved floating-point Python trace; the RTL uses a separately verified Q8 update.')+card('Stress cases · error rate',table(['Case','Fixed','Adaptive','Baseline'],tb),'Two channels · 8,112 evaluated symbols per case and method.')+'</div>'+note('<b>Literal DC issue:</b> y = x − MIN + 95 is always ≥95 when the window includes x, while the reconstructed −1 decision needs y &lt;95. DC bypass is the default. The update rule, rounding and missing constants are documented.','warn')))

tb=[]
for c in val['configurations']:
    tb.append([str(c['lanes']),'On' if c['dc_enabled'] else 'Off','Q8' if c['adaptive_q8'] else 'Fixed',f'{c["core"]["symbols_checked"]:,}',f'{c["analyzer"]["symbols_checked"]:,}','<span class="pass">PASS</span>'])
log=(F/'results/verification/L8_DC0_A0_analyzer.log').read_text().splitlines()[0]
body='<div class="grid">'+card('All eight RTL configurations',table(['Samples/clock','DC','Thresholds','Core symbols','Two-channel symbols','Match'],tb),'Each configuration includes a core test and a two-channel packed-output test.')+card('Checks beyond symbol values','<ul><li>Corrected ADC and raw/filtered levels</li><li>Exact sampling indices and output order</li><li>Empty, short and partial input blocks</li><li>One-, two- and three-sample pulses</li><li>Source bubbles and output stalls</li><li>End-of-capture flushing and reset</li><li>Independent channel decisions</li><li>Host record format and parser</li></ul>'+note('PASS means agreement with the independent reference. It does not mean zero error against a noisy transmitter.'))+'</div>'
body+=card('Recorded Icarus log · 8 samples/clock, fixed thresholds, DC off',f'<pre>{esc(log)}</pre>','The original log and machine-readable validation are included in 03_FPGA/results/verification/.')
data.append(dict(id='rtl',title='Does the hardware execute the intended algorithm?',subtitle='Icarus Verilog 12.0 • streaming SystemVerilog compared with the independent Python reference',stats=stat('Symbol comparisons','73,206','Across all eight settings')+stat('Channel capture tests','1,440','Includes core + paired-channel tests')+stat('Configuration result','8 / 8 matched','16 RTL executions · recorded suite','good'),body=body))

pt=[[f'{p["configuration"].split("_")[0][1:]} sample(s)/clock',f'{p["channel_samples_checked"]:,}',f'{p["symbols_checked"]:,}','<span class="pass">PASS</span>'] for p in post]
st=[[f'{l} sample(s)/clock',f'{s["LUT_cells"]:,}',f'{s["FF_cells"]:,}',str(s['inferred_latches'])] for l,s in zip([1,8],syn)]
data.append(dict(id='synthesis',title='From RTL to FPGA logic resources',subtitle='Yosys 0.33 • generic Xilinx 7-series mapping • two channels, packers and host multiplexer',stats=stat('Synthesized mode','Fixed · DC off','1 and 8 samples per clock')+stat('Inferred latches','0','Structural checks passed')+stat('Mapped-netlist outputs','2,168 matched','Functional simulation; no timing delays','good'),body='<div class="grid">'+card('Resource cost of eight-sample processing',img('fpga_resources.png'),'Chronological dependencies are unrolled; the larger mode uses more logic.')+card('Mapped resources',table(['Mode','LUT','Flip-flop','Latch'],st)+ '<h3 class="second">Post-synthesis functional test</h3>'+table(['Mode','Samples','Symbols','Match'],pt))+'</div>'+note('<b>Implemented:</b> digital reconstruction and functional mapped-netlist checks. <b>Still to verify:</b> physical ADC/clock interface, board I/O, place-and-route timing and real-channel measurements. Vivado scripts are provided but were not run. The 100 MHz / 800 MS/s target has not been measured.')))

css='''*{box-sizing:border-box}body{margin:0;background:#edf0f4;color:#172033;font-family:Arial,Helvetica,sans-serif;font-size:14px}button{font:inherit}.window{height:36px;background:#e3e7ed;border-bottom:1px solid #cdd4df;display:flex;align-items:center;gap:9px;padding:0 18px;font-size:12px;color:#4b5563}.dot{width:9px;height:9px;border-radius:50%;background:#bbc3cf}.window .location{margin:auto;font-family:monospace;font-size:12px}.layout{display:flex;min-height:calc(100vh - 36px)}aside{width:205px;flex-shrink:0;background:#182337;color:#d6dce6;padding:25px 17px;display:flex;flex-direction:column}.brand{font-weight:700;font-size:23px;letter-spacing:1px;color:white}.brand small{font-size:11px;letter-spacing:.7px;display:block;font-weight:400;margin-top:9px;color:#9cabc0}.rule{height:1px;background:#344159;margin:24px 0 18px}.nav{display:block;width:100%;border:0;color:#b8c6d9;background:transparent;text-align:left;padding:14px 10px;border-radius:6px;cursor:pointer;margin:3px 0;font-size:13px}.nav.active{background:#2c4161;color:#fff}.nav .num{opacity:.55;margin-right:9px}.asidefoot{margin-top:auto;color:#96a5bb;font-size:11px;line-height:1.8;padding-top:25px}main{padding:24px 28px;width:calc(100% - 205px);max-width:1600px}.mast{display:flex;justify-content:space-between;align-items:center;margin-bottom:21px;font-size:11px;color:#64748b}.pill{padding:6px 9px;border:1px solid #cbd5e1;border-radius:5px;background:#fff}h1{font-size:25px;letter-spacing:-.35px;margin:0 0 8px;font-weight:600}.subtitle{color:#64748b;margin:0 0 20px;font-size:13px;line-height:1.5}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:15px;margin-bottom:18px}.stat{background:#fff;border:1px solid #d9e0e9;border-radius:7px;padding:15px 18px}.stat small{display:block;color:#64748b;font-size:11px;margin-bottom:8px}.stat strong{font-size:24px;display:block;font-weight:600}.stat span{font-size:11px;color:#64748b;display:block;margin-top:7px}.stat.warn strong{color:#9a3412}.stat.good strong{color:#0f766e}.grid{display:grid;grid-template-columns:minmax(0,1.65fr) minmax(330px,1fr);gap:17px;margin-bottom:16px}.grid.signal{grid-template-columns:minmax(0,2.5fr) minmax(300px,1fr)}.card{background:white;border:1px solid #d9e0e9;border-radius:7px;padding:19px;overflow:hidden}.card h3{font-size:14px;margin:0 0 13px;font-weight:600}.sub{font-size:11px;color:#64748b;line-height:1.6;margin:-4px 0 12px}.plot{display:block;width:100%;height:auto}.note{background:#f5f7fa;border:1px solid #dce3eb;border-radius:5px;padding:13px 15px;font-size:12px;color:#475569;line-height:1.65;margin-top:13px}.note.warn{background:#fff8ed;border-color:#eed9bc;color:#7c4322}table{width:100%;border-collapse:collapse;font-size:12px}th{background:#f5f7fa;color:#64748b;font-size:10px;font-weight:500;text-align:left;padding:11px 8px;border-bottom:1px solid #dbe3ee}td{padding:12px 8px;border-bottom:1px solid #edf1f5;line-height:1.4}tr:last-child td{border-bottom:0}.pass{color:#0f766e;background:#ecf8f3;border:1px solid #c7e8dc;padding:3px 7px;border-radius:4px;font-size:10px;font-weight:700}.code{font-family:monospace;color:#475569;background:#f5f7fa;padding:13px;margin-top:17px;font-size:11px;line-height:1.9}pre{white-space:pre-wrap;background:#182337;color:#d9e5ee;border-radius:5px;padding:17px;font-size:12px;margin:0;line-height:1.7}ul{padding-left:18px;font-size:13px;line-height:1.85;color:#475569;margin:5px 0}.second{margin-top:25px!important}.page[hidden]{display:none}.foot{display:flex;justify-content:space-between;font-size:10px;color:#7b8799;border-top:1px solid #d9e0e9;padding-top:13px;margin-top:18px}@media(max-width:900px){aside{width:155px}main{width:calc(100% - 155px);padding:18px}.grid,.grid.signal{grid-template-columns:1fr}.stats{grid-template-columns:1fr}h1{font-size:21px}}'''
navtitles=['Signal decoding','Noise performance','Thresholds & DC','RTL verification','FPGA synthesis']
nav=''.join(f'<button class="nav" data-page="{d["id"]}" onclick="showPage(\'{d["id"]}\')"><span class="num">0{i+1}</span>{navtitles[i]}</button>' for i,d in enumerate(data))
pages=''.join(f'<section class="page" id="{d["id"]}" hidden><h1>{d["title"]}</h1><p class="subtitle">{d["subtitle"]}</p><div class="stats">{d["stats"]}</div>{d["body"]}<div class="foot"><span>US11405248B2 · documented reconstruction</span><span>Recorded results · 04 Oct 2026 · view {i+1}/5</span></div></section>' for i,d in enumerate(data))
doc='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PAM3 Experiment Notebook</title><style>'+css+'</style></head><body><div class="window"><i class="dot"></i><i class="dot"></i><i class="dot"></i><span class="location">PAM3 / experiment notebook / recorded results</span><span>Local report</span></div><div class="layout"><aside><div class="brand">PAM3<small>EXPERIMENT NOTEBOOK</small></div><div class="rule"></div>'+nav+'<div class="asidefoot">Python · SystemVerilog<br>Icarus Verilog · Yosys<br><br>Digital reconstruction<br>Synthetic channel data<br>Board measurements pending</div></aside><main><div class="mast"><span>Project / ternary signal detector / results</span><span class="pill">Saved experiment evidence</span></div>'+pages+'</main></div><script>function showPage(id){document.querySelectorAll(".page").forEach(x=>x.hidden=x.id!==id);document.querySelectorAll(".nav").forEach(x=>x.classList.toggle("active",x.dataset.page===id));location.hash=id;}showPage(location.hash.slice(1)||"signal");window.addEventListener("hashchange",()=>showPage(location.hash.slice(1)||"signal"));</script></body></html>'
write(V/'index.html',doc)
write(V/'figure_data.json',json.dumps(dict(noise=noise,stress=stress,literal_dc_30=dc30,rtl=dict(total_symbols_checked=val['total_symbols_checked'],total_channel_frames=val['total_channel_frames']),synthesis=syn,post_synthesis=post),indent=2))
