from pathlib import Path
import json,csv,math
from PIL import Image,ImageDraw,ImageFont
from matplotlib.font_manager import findfont

R=Path(__file__).resolve().parents[1];V=R/'01_Results';O=V/'screenshots';O.mkdir(exist_ok=True)
D=json.loads((V/'figure_data.json').read_text());validation=json.loads((R/'03_FPGA/results/verification/validation.json').read_text())
scale=1.5
fontpath=findfont('DejaVu Sans');boldpath=findfont('DejaVu Sans:weight=bold');monopath=findfont('DejaVu Sans Mono')
def font(size,bold=False,mono=False):return ImageFont.truetype(monopath if mono else boldpath if bold else fontpath,round(size*scale))
BG='#edf0f4';WHITE='#ffffff';INK='#172033';GRAY='#64748b';BORDER='#d9e0e9';BLUE='#2563eb';TEAL='#0f766e';ORANGE='#9a3412'
def xy(x):return round(x*scale)
checks=[]
class Screen:
 def __init__(self,active,title,sub):
  self.im=Image.new('RGB',(2400,1500),BG);self.d=ImageDraw.Draw(self.im);self.bounds=[]
  self.rect(0,0,1600,36,'#e3e7ed');self.rect(0,36,205,1000,'#182337')
  for x in [20,37,54]:self.d.ellipse((xy(x),xy(14),xy(x+8),xy(22)),fill='#bbc3cf')
  self.text(510,11,'PAM3 / experiment notebook / recorded results',11,GRAY,mono=True)
  self.text(1480,11,'Local report',11,GRAY)
  self.text(23,65,'PAM3',24,'white',bold=True);self.text(23,105,'EXPERIMENT NOTEBOOK',10,'#9cabc0')
  self.line(23,138,182,138,'#344159')
  names=['Signal decoding','Noise performance','Thresholds & DC','RTL verification','FPGA synthesis']
  for i,n in enumerate(names):
   y=164+i*55
   if i==active:self.rect(15,y-9,191,y+34,'#2c4161',radius=6)
   self.text(25,y,f'0{i+1}',11,'#91a1b7');self.text(52,y,n,12,'white' if i==active else '#b8c6d9')
  self.text(23,842,'Python · SystemVerilog',11,'#9cabc0');self.text(23,867,'Icarus Verilog · Yosys',11,'#9cabc0')
  self.text(23,923,'Recorded simulation data',10,'#9cabc0');self.text(23,945,'Board tests pending',10,'#9cabc0')
  self.text(235,62,'Project / ternary signal detector / results',11,GRAY)
  self.rect(1350,53,1570,80,WHITE,radius=5);self.text(1363,61,'Saved experiment evidence',11,GRAY)
  self.text(235,108,title,25,INK,bold=True);self.text(235,152,sub,12,GRAY)
  self.line(235,950,1570,950,BORDER);self.text(235,965,'US11405248B2 · documented reconstruction',10,GRAY)
  self.text(1158,965,f'Recorded results · 04 Oct 2026 · view {active+1}/5',10,GRAY)
 def rect(self,x,y,x2,y2,fill,outline=None,radius=0):
  self.d.rounded_rectangle(tuple(map(xy,[x,y,x2,y2])),radius=xy(radius),fill=fill,outline=outline,width=xy(1))
 def line(self,x,y,x2,y2,color):self.d.line(tuple(map(xy,[x,y,x2,y2])),fill=color,width=xy(1))
 def text(self,x,y,s,size=13,color=INK,bold=False,mono=False):
  self.d.text((xy(x),xy(y)),str(s),font=font(size,bold,mono),fill=color)
 def wrap(self,x,y,s,width,size=12,color=GRAY,lineheight=19,bold=False):
  f=font(size,bold);words=s.split();line='';lines=[]
  for w in words:
   test=(line+' '+w).strip()
   if self.d.textlength(test,font=f)>xy(width) and line:lines.append(line);line=w
   else:line=test
  if line:lines.append(line)
  for line in lines:self.text(x,y,line,size,color,bold);y+=lineheight
  return y
 def stats(self,ss):
  for i,(label,value,detail,color) in enumerate(ss):
   x=235+i*450;self.rect(x,193,x+435,294,WHITE,BORDER,7)
   self.text(x+17,207,label,11,GRAY);self.text(x+17,230,value,23,color,bold=True);self.text(x+17,270,detail,11,GRAY)
 def card(self,x,y,w,h,title,sub=None):
  self.rect(x,y,x+w,y+h,WHITE,BORDER,7);self.text(x+18,y+18,title,14,INK,bold=True)
  if sub:self.wrap(x+18,y+45,sub,w-36,11,lineheight=17)
 def plot(self,name,x,y,w,h):
  a=Image.open(V/'assets'/name).convert('RGB');a.thumbnail((xy(w),xy(h)),Image.Resampling.LANCZOS)
  self.im.paste(a,(xy(x)+(xy(w)-a.width)//2,xy(y)+(xy(h)-a.height)//2))
 def note(self,x,y,w,h,s,warn=False):
  self.rect(x,y,x+w,y+h,'#fff8ed' if warn else '#f5f7fa','#eed9bc' if warn else BORDER,5)
  bottom=self.wrap(x+14,y+12,s,w-28,12,ORANGE if warn else '#475569',lineheight=20)
  assert bottom<=y+h+2,('note overflow',bottom,y+h)
 def table(self,x,y,widths,headers,rows,rowheight=40,size=12):
  w=sum(widths);self.rect(x,y,x+w,y+32,'#f5f7fa');xx=x
  for h,ww in zip(headers,widths):self.text(xx+9,y+10,h,10,GRAY);xx+=ww
  for j,row in enumerate(rows):
   yy=y+32+j*rowheight;xx=x
   for cell,ww in zip(row,widths):
    color=TEAL if cell=='PASS' else INK
    if self.d.textlength(str(cell),font=font(size))>xy(ww-14):raise AssertionError(('table overflow',cell,ww))
    self.text(xx+9,yy+12,cell,size,color,bold=cell=='PASS');xx+=ww
   self.line(x,yy+rowheight,x+w,yy+rowheight,'#edf1f5')
  return y+32+len(rows)*rowheight
 def save(self,name):
  self.im.save(O/name,optimize=True);checks.append(dict(file=name,size=list(self.im.size),passed=True))

s=Screen(0,'From ADC samples to PAM3 symbols','Saved simulation trace · Master channel · SNR 30 dB · fixed thresholds, DC off')
import numpy as np
with np.load(R/'02_Simulation/results/traces/SNR_30_master.npz') as z:
 p=z['patent_fixed_bypass__points'];count=int(((p>=480)&(p<660)).sum())
s.stats([('ADC boundary','8-bit / 800 MS/s','Nominal sampling model',INK),('Receiver thresholds','140 / 95 / 160 / 80','Slope-aware level decisions',INK),('Shown window',f'{count} output symbols','ADC samples 480–659 · one run',INK)])
s.card(235,315,930,543,'Signal, decoded levels and chosen sampling points','Dots mark the samples actually selected by the receiver.')
s.plot('signal_decode.png',251,386,898,452)
s.card(1182,315,388,543,'What the code does')
s.table(1199,367,[107,241],['Stage','Operation'],[['1 · DC','Bypassed in this view'],['2 · Level','Slope + four thresholds'],['3 · Spike','Isolated runs ≤2 samples'],['4 · Edges','Must events + filters'],['5 · Timing','12-sample step + resync'],['6 · Output','Read filtered level']],rowheight=42,size=11)
s.note(1200,673,348,107,'The transmitter trace is used for evaluation only. Its labels and timing are not inputs to the receiver.')
s.text(1200,804,'pam3/model.py',11,GRAY,mono=True);s.text(1200,827,'rtl/pam3_stream_core.sv',11,GRAY,mono=True)
s.note(235,877,1335,55,'Source: SNR_30_master.npz · behavioural channel data; this is not a measured cable.')
s.save('01_Signal_Decoding.png')

s=Screen(1,'How noise changes the decoding result','Performance against known transmitted symbols · recorded Monte Carlo runs')
s.stats([('30 dB','0 / 40,560','No error observed in this test',INK),('18 dB','0.552% error','224 failed symbol intervals',INK),('10 dB','21.635% error','8,775 failed symbol intervals',INK)])
s.card(235,315,835,519,'Noise sweep','Five seeds × two channels; 40,560 evaluated symbols per SNR and method.')
s.plot('noise_test.png',252,387,801,427)
s.card(1087,315,483,519,'Fixed receiver · DC off')
s.table(1105,365,[78,225,145],['SNR','Errors / evaluated','Rate'],[[f'{k} dB',f'{D["noise"][str(k)]["errors"]:,} / 40,560',f'{D["noise"][str(k)]["pct"]:.3f}%'] for k in [30,18,10]],rowheight=42)
s.note(1105,541,448,88,'A symbol succeeds only if its interval contains exactly one output, with the correct value.')
s.table(1105,648,[270,178],['At 18 dB','Failed intervals'],[['Wrong value','86'],['Missing output','1'],['Repeated outputs','137'],['Total','224']],rowheight=33)
s.note(235,851,1335,79,'Metric: 100 × failed symbol intervals / evaluated intervals. First 32 and last 8 symbols excluded. Baseline and adaptive results use the same scale. No universal winner is assumed.')
s.save('02_Noise_Performance.png')

s=Screen(2,'Threshold tracking — and a DC ambiguity','Adaptive update: engineering reconstruction; the patent does not disclose the exact equation.')
s.stats([('Gain-step test · fixed','6.805% error','552 / 8,112 evaluated symbols',INK),('Gain-step test · adaptive','0.136% error','11 / 8,112 evaluated symbols',INK),('Literal DC · 30 dB','65.303% error','26,487 / 40,560 · documented limit',ORANGE)])
s.card(235,315,780,470,'Four thresholds follow a change in amplitude','Saved floating-point Python trace; RTL uses a separately verified Q8 update.')
s.plot('adaptive_thresholds.png',250,386,750,377)
s.card(1032,315,538,470,'Stress cases · total symbol error','Two channels; 8,112 evaluated symbols per case and method.')
labels={'gain_step_minus035':'Gain 1 → 0.65','offset_plus25':'DC +25 codes','offset_minus25':'DC −25 codes','slow_edges':'Slow edges'}
tb=[[labels[c]]+[f'{D["stress"][c][m]["pct"]:.3f}%' for m in ['patent_fixed_bypass','inferred_adaptive_bypass','two_threshold_fixed_clock']] for c in labels]
s.table(1050,398,[168,105,115,115],['Case','Fixed','Adaptive','Baseline'],tb,rowheight=50,size=12)
s.note(1050,665,502,92,'The baseline wins some cases. These results identify strengths and limitations; they do not prove one method is always best.')
s.note(235,805,1335,124,'Literal DC issue: y = x − MIN + 95 is always ≥95 when the window includes x, while the reconstructed −1 decision needs y <95. DC bypass is the default. The adaptive update, rounding and missing constants are documented in PATENT_ASSUMPTIONS.md.',warn=True)
s.save('03_Thresholds_and_DC.png')

s=Screen(3,'Does the hardware execute the intended algorithm?','Icarus Verilog 12.0 · streaming SystemVerilog compared with an independent Python reference')
s.stats([('Symbol comparisons','73,206','Across all eight settings',INK),('Channel capture tests','1,440','Core and paired-channel tests',INK),('Configuration result','8 / 8 matched','16 RTL executions · recorded suite',TEAL)])
s.card(235,315,895,459,'All eight RTL configurations','Each setting includes a core test and a two-channel packed-output test.')
tb=[[str(c['lanes']),'On' if c['dc_enabled'] else 'Off','Q8' if c['adaptive_q8'] else 'Fixed',f'{c["core"]["symbols_checked"]:,}',f'{c["analyzer"]["symbols_checked"]:,}','PASS'] for c in validation['configurations']]
s.table(253,389,[148,62,130,145,229,145],['Samples/clock','DC','Thresholds','Core symbols','Two-channel symbols','Match'],tb,rowheight=39)
s.card(1147,315,423,459,'Checks beyond symbol values')
yy=369
for text in ['Corrected ADC; raw/filtered levels','Exact sampling indices and order','Empty, short and partial inputs','One-, two-, three-sample pulses','Source bubbles and output stalls','End-of-capture flushing and reset','Independent channel decisions','Host record format and parser']:
 s.text(1166,yy,'• '+text,12,'#475569');yy+=31
s.note(1166,636,385,113,'PASS means agreement with the reference. It does not mean zero error against a noisy transmitter.')
s.card(235,795,1335,135,'Recorded Icarus log · eight samples/clock, fixed thresholds, DC off')
log=(R/'03_FPGA/results/verification/L8_DC0_A0_analyzer.log').read_text().splitlines()[0]
s.rect(253,841,1552,883,'#182337',radius=5);s.text(266,855,log,12,'#d9e5ee',mono=True)
s.text(253,902,'Original logs and machine-readable validation are included in 03_FPGA/results/verification/.',11,GRAY)
s.save('04_RTL_Verification.png')

s=Screen(4,'From RTL to FPGA logic resources','Yosys 0.33 · generic Xilinx 7-series mapping · two channels, packers and host multiplexer')
s.stats([('Synthesized mode','Fixed · DC off','1 and 8 samples per clock',INK),('Inferred latches','0','Structural checks passed',INK),('Mapped-netlist outputs','2,168 matched','Functional simulation; no timing delays',TEAL)])
s.card(235,315,790,452,'Resource cost of eight-sample processing','More samples per clock replicate the chronological computation chain.')
s.plot('fpga_resources.png',254,398,752,337)
s.card(1042,315,528,452,'Mapped resources')
s.table(1061,365,[154,122,126,87],['Mode','LUT','Flip-flop','Latch'],[[f'{l} sample(s)/clock',f'{q["LUT_cells"]:,}',f'{q["FF_cells"]:,}','0'] for l,q in zip([1,8],D['synthesis'])],rowheight=42,size=12)
s.text(1061,515,'Post-synthesis functional test',14,INK,bold=True)
s.table(1061,554,[154,115,115,105],['Mode','Samples','Symbols','Match'],[[f'{p["configuration"].split("_")[0][1:]} sample(s)/clock',f'{p["channel_samples_checked"]:,}',f'{p["symbols_checked"]:,}','PASS'] for p in D['post_synthesis']],rowheight=42,size=12)
s.note(235,789,1335,140,'Implemented: digital reconstruction and mapped-netlist functional checks. Still to verify: physical ADC/clock interface, board I/O, place-and-route timing and real-channel measurements. Vivado scripts are provided but were not run. The 100 MHz / 800 MS/s target has not been measured.')
s.save('05_FPGA_Synthesis.png')

# The user asked for a screenshot theme. These are precise raster result views,
# not fabricated screenshots of an unavailable application or physical board.
for file in [R/'README.md',R/'START_HERE_FA.md']:
 text=file.read_text()
 text=text.replace('are actual browser captures of this\nlocal report, generated from the included experiment data. They are not IDE,\nVivado, board, or live-instrument screenshots. The header labels recorded data.', 'are screenshot-style result views rendered from the included experiment data.\nThey are not IDE, Vivado, board, or live-instrument screenshots. The header\nlabels recorded data; the local HTML report presents the same evidence.')
 text=text.replace('تصاویر، اسکرین‌شات همین گزارش محلی‌اند و\nاز داده‌های واقعیِ آزمایش‌های شبیه‌سازی ساخته شده‌اند.', 'تصاویر با ظاهر صفحه نرم‌افزار طراحی شده‌اند و\nاز داده‌های واقعیِ آزمایش‌های شبیه‌سازی ساخته شده‌اند. اسکرین‌شات Vivado یا برد نیستند.')
 file.write_text(text,encoding='utf-8')
(V/'image_validation.json').write_text(json.dumps({'passed':True,'rendering':'Pillow raster result views, precise Matplotlib charts','not_live_instrument_screenshots':True,'images':checks},indent=2))
print(json.dumps(checks,indent=2))
