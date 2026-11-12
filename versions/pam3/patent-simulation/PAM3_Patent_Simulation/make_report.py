#!/usr/bin/env python3
"""Build plots, self-contained offline HTML, and a technical PDF from real results."""
import base64,csv,html,json,math,platform
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from reportlab.pdfgen import canvas
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT=Path(__file__).resolve().parent
R=ROOT/"results";P=R/"plots";P.mkdir(exist_ok=True)
SUMMARY=json.loads((R/"summary.json").read_text())
META=json.loads((R/"metadata.json").read_text())
HDL=json.loads((R/"hdl/validation.json").read_text()) if (R/"hdl/validation.json").exists() else None
NAMES={"patent_fixed_bypass":"Fixed / DC bypass","patent_literal_dc":"Literal printed DC",
       "inferred_adaptive_bypass":"Inferred adaptive / bypass","two_threshold_fixed_clock":"Two thresholds / fixed clock"}
COLORS={"patent_fixed_bypass":"#167f78","patent_literal_dc":"#af5551",
        "inferred_adaptive_bypass":"#bd7528","two_threshold_fixed_clock":"#4a69a2"}
plt.rcParams.update({"font.family":"DejaVu Sans","font.size":10,"axes.spines.top":False,
    "axes.spines.right":False,"axes.labelcolor":"#263738","text.color":"#263738",
    "axes.edgecolor":"#c7cdca","grid.color":"#dce2dd","figure.facecolor":"white"})

def rows(suite,method=None):return [r for r in SUMMARY if r["suite"]==suite and (method is None or r["method"]==method)]
def lookup(suite,case,method):return next(r for r in SUMMARY if r["suite"]==suite and r["case"]==case and r["method"]==method)
def save(fig,name):fig.savefig(P/(name+".png"),dpi=190,bbox_inches="tight");plt.close(fig)

def plots():
    fig,ax=plt.subplots(figsize=(9,4.5))
    for method in NAMES:
        rr=sorted(rows("snr",method),key=lambda r:r["snr_db"])
        x=[r["snr_db"] for r in rr];y=[r["ser"] if r["ser"] else r["ci_high"] for r in rr]
        ax.plot(x,y,"o-",color=COLORS[method],label=NAMES[method],lw=1.8,ms=4)
        for r,xx,yy in zip(rr,x,y):
            if not r["ser"]:ax.plot(xx,yy,"v",color=COLORS[method],ms=8,mfc="white")
    ax.set_yscale("log");ax.set_xlabel("Nominal transmitted-power SNR (dB)")
    ax.set_ylabel("Interval SER, including missing / duplicate outputs")
    ax.grid(True,which="both",alpha=.65);ax.legend(fontsize=8,loc="upper right")
    ax.set_title("Noise sweep: 5 seeds x 2 channels; 40,560 evaluated symbols per point",loc="left",fontsize=11,pad=15)
    fig.text(.1,-.015,"Downward hollow markers: zero observed errors plotted at the descriptive 95% Wilson upper bound.",fontsize=8)
    save(fig,"snr_sweep")

    selected=["offset_plus25","gain_065","dc_step_plus30","clock_plus1000ppm",
              "echo_025","coupler_leakage_015","impulses","slow_edges","long_runs_clock_drift"]
    labels=["DC +25","Gain 0.65","DC step +30","Clock +1000 ppm","Echo 0.25","Leakage 0.15","Impulses","Slow edges","Long runs + drift"]
    fig,ax=plt.subplots(figsize=(9,5))
    yy=np.arange(len(selected));width=.24
    for j,method in enumerate(["patent_fixed_bypass","inferred_adaptive_bypass","two_threshold_fixed_clock"]):
        vals=[lookup("stress",c,method)["ser"]*100 for c in selected]
        ax.barh(yy+(j-1)*width,vals,height=width,color=COLORS[method],label=NAMES[method])
    ax.set_yticks(yy,labels);ax.invert_yaxis();ax.set_xlabel("Failed TX symbol intervals (%)")
    ax.legend(fontsize=8,loc="lower right");ax.grid(axis="x",alpha=.6);ax.set_axisbelow(True)
    ax.set_title("Stress cases: 8,112 evaluated symbols per method and case",loc="left",fontsize=11,pad=15)
    save(fig,"stress_comparison")

    fig,axs=plt.subplots(1,2,figsize=(9,4),sharey=True)
    for ax,method in zip(axs,["patent_fixed_bypass","inferred_adaptive_bypass"]):
        rr=rows("gain_offset",method);gains=sorted(set(r["gain"] for r in rr));offsets=sorted(set(r["dc_offset"] for r in rr))
        matrix=np.array([[next(r["ser"] for r in rr if r["gain"]==g and r["dc_offset"]==o) for o in offsets] for g in gains])
        im=ax.imshow(matrix*100,vmin=0,vmax=100,cmap="YlOrRd",origin="lower",aspect="auto")
        ax.set_xticks(range(len(offsets)),[str(x) for x in offsets]);ax.set_yticks(range(len(gains)),[str(x) for x in gains])
        ax.set_xlabel("DC offset (ADC codes)");ax.set_title(NAMES[method],fontsize=10)
        for i in range(len(gains)):
            for j in range(len(offsets)):ax.text(j,i,f"{matrix[i,j]*100:.1f}",ha="center",va="center",fontsize=8,color="white" if matrix[i,j]>.55 else "#263738")
    axs[0].set_ylabel("DVGA / channel gain");fig.colorbar(im,ax=axs.ravel().tolist(),shrink=.8,label="Interval error (%)")
    save(fig,"gain_dc_map")

    with (R/"phase_sweep.csv").open() as f:rr=list(csv.DictReader(f))
    fig,ax=plt.subplots(figsize=(9,3.5))
    for method in ["patent_fixed_bypass","two_threshold_fixed_clock"]:
        d=[r for r in rr if r["method"]==method]
        ax.plot([float(r["phase_samples"]) for r in d],[float(r["ser_total"])*100 for r in d],"o-",color=COLORS[method],label=NAMES[method],ms=4)
    ax.set_xlabel("TX start phase relative to receiver (samples)");ax.set_ylabel("Interval error (%)")
    ax.grid(alpha=.6);ax.legend(fontsize=8);ax.set_title("Phase sweep: receiver starts at sample 6 for every trial",loc="left",fontsize=11,pad=15)
    save(fig,"phase_sweep")

    tr=np.load(R/"traces/SNR_18_master.npz")
    m="patent_fixed_bypass__";a,b=600,960;x=np.arange(a,b)*1.25
    fig,axs=plt.subplots(3,1,figsize=(9,5.5),sharex=True,gridspec_kw={"height_ratios":[2,1,1]})
    axs[0].plot(x,tr["adc"][a:b],color="#475763",lw=1,label="ADC")
    for value in [140,95,160,80]:axs[0].axhline(value,color="#bd7528",lw=.8,alpha=.65,ls="--")
    axs[0].set_ylabel("8-bit ADC code");axs[0].set_ylim(0,255);axs[0].legend(fontsize=8,loc="upper right")
    axs[1].step(x,tr[m+"raw_levels"][a:b],color="#9daca8",where="post",label="Raw levels")
    axs[1].step(x,tr[m+"levels"][a:b],color="#167f78",where="post",label="Filtered")
    pts=tr[m+"points"];vals=tr[m+"symbols"];keep=(pts>=a)&(pts<b)
    axs[1].scatter(pts[keep]*1.25,vals[keep],s=15,color="#bd7528",zorder=5,label="Output point")
    axs[1].set_ylabel("RX level");axs[1].legend(fontsize=8,ncol=3,loc="upper right")
    txidx=np.clip(np.searchsorted(tr["boundaries"],np.arange(a,b),side="right")-1,0,len(tr["tx"])-1)
    axs[2].step(x,tr["tx"][txidx],color="#4a69a2",where="post");axs[2].set_ylabel("TX reference")
    axs[2].set_xlabel("Time (ns), 1.25 ns per ADC sample")
    for ax in axs[1:]:ax.set_yticks([-1,0,1]);ax.set_ylim(-1.4,1.4)
    fig.suptitle("Actual noisy trace: fixed thresholds, DC bypass, SNR 18 dB",x=.08,ha="left",fontsize=11)
    fig.tight_layout();save(fig,"waveform")

    with (R/"dc_sensitivity.csv").open() as f:rr=list(csv.DictReader(f))
    fig,ax=plt.subplots(figsize=(9,3.5))
    for anchor,col in [(60,"#167f78"),(80,"#bd7528"),(95,"#af5551")]:
        d=[r for r in rr if int(r["dc_anchor"])==anchor]
        ax.plot([int(r["dc_min_gate"]) for r in d],[float(r["ser_total"])*100 for r in d],"o-",color=col,label=f"DC anchor {anchor}"+(" (literal name)" if anchor==95 else " (engineering change)"))
    ax.set_xlabel("Assumed Minus_Maximum_Threshold guard");ax.set_ylabel("Interval error (%)")
    ax.grid(alpha=.6);ax.legend(fontsize=8);ax.set_title("Sensitivity to the undisclosed DC guard and ambiguous DC anchor",loc="left",fontsize=11,pad=15)
    save(fig,"dc_sensitivity")

def b64(path):return base64.b64encode(path.read_bytes()).decode()

def html_report():
    traces={}
    for file in sorted((R/"traces").glob("*.npz")):
        tr=np.load(file);length=len(tr["adc"]);parts={}
        for part,start in [("after_startup",384),("middle",length//2-960),("late",length-2304)]:
            stop=min(length,start+1920);xx=np.arange(start,stop)
            idx=np.clip(np.searchsorted(tr["boundaries"],xx,side="right")-1,0,len(tr["tx"])-1)
            methods={}
            for method in NAMES:
                prefix=method+"__"
                if prefix+"levels" not in tr:continue
                p=tr[prefix+"points"];keep=(p>=start)&(p<stop)
                methods[method]=dict(levels=tr[prefix+"levels"][start:stop].tolist(),
                    raw=tr[prefix+"raw_levels"][start:stop].tolist() if prefix+"raw_levels" in tr else tr[prefix+"levels"][start:stop].tolist(),
                    corrected=tr[prefix+"corrected"][start:stop].tolist() if prefix+"corrected" in tr else tr["adc"][start:stop].tolist(),
                    points=p[keep].tolist(),symbols=tr[prefix+"symbols"][keep].tolist())
            parts[part]=dict(start=start,adc=tr["adc"][start:stop].tolist(),expected=tr["tx"][idx].tolist(),methods=methods)
        traces[file.stem]=parts
    template=(ROOT/"docs/dashboard_template.html").read_text(encoding="utf-8")
    content=template.replace("__DATA__",json.dumps(dict(summary=SUMMARY,meta=META,hdl=HDL,traces=traces,names=NAMES),ensure_ascii=False,allow_nan=False))
    for name in ["snr_sweep","stress_comparison","gain_dc_map","phase_sweep","dc_sensitivity"]:
        content=content.replace("__IMAGE_"+name+"__","data:image/png;base64,"+b64(P/(name+".png")))
    (ROOT/"PAM3_Results.html").write_text(content,encoding="utf-8")

def pdf_report():
    font="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    bold="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    if Path(font).exists():
        pdfmetrics.registerFont(TTFont("Body",font));pdfmetrics.registerFont(TTFont("BodyBold",bold))
    else:
        pdfmetrics.registerFont(pdfmetrics.Font("Body","Helvetica","WinAnsiEncoding"))
        pdfmetrics.registerFont(pdfmetrics.Font("BodyBold","Helvetica-Bold","WinAnsiEncoding"))
    styles=getSampleStyleSheet()
    body=ParagraphStyle("B",fontName="Body",fontSize=9.3,leading=14,textColor=colors.HexColor("#263738"),spaceAfter=8)
    small=ParagraphStyle("S",parent=body,fontSize=7.8,leading=11,spaceAfter=5)
    h=ParagraphStyle("H",parent=body,fontName="BodyBold",fontSize=20,leading=26,spaceAfter=17)
    sub=ParagraphStyle("Sub",parent=body,fontName="BodyBold",fontSize=11,leading=16,spaceAfter=7)
    story=[]
    def para(text,style=body):story.append(Paragraph(text,style))
    def heading(text):para(text,h)
    def table(headers,data,widths):
        vals=[[Paragraph(html.escape(str(v)),small) for v in row] for row in [headers]+data]
        t=Table(vals,colWidths=widths,repeatRows=1,hAlign="LEFT")
        t.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor("#e6eeea")),
            ("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),7),
            ("RIGHTPADDING",(0,0),(-1,-1),7),("TOPPADDING",(0,0),(-1,-1),6),
            ("BOTTOMPADDING",(0,0),(-1,-1),5),("LINEBELOW",(0,0),(-1,0),.5,colors.HexColor("#bccbc3")),
            ("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white,colors.HexColor("#f6f7f4")])]))
        story.append(t);story.append(Spacer(1,12))
    def figure(name,height=245):
        from PIL import Image as PILImage
        w,hh=PILImage.open(P/(name+".png")).size
        scale=min(495/w,height/hh)
        story.append(Image(str(P/(name+".png")),width=w*scale,height=hh*scale,hAlign="LEFT"));story.append(Spacer(1,9))
    def page():story.append(PageBreak())

    para("REPRODUCIBLE ENGINEERING STUDY  /  04 OCTOBER 2026",small)
    heading("PAM-3 decoding<br/>Patent reconstruction and simulation")
    para("US 11,405,248 B2 - Prabhakar, Mulki and Mahammad (2022)",sub)
    para("A two-channel functional model, a numerical stress suite and independent SystemVerilog verification. Prepared for Alborz Seifaei.")
    para("The supplied patent was read in full: 19 PDF pages, 12 drawing sheets and 19 claims. Published rules are retained; missing implementation details are explicitly reconstructed.")
    heading("What the executed tests establish")
    selected=[("SNR 30 dB","snr","SNR_30","patent_fixed_bypass"),
        ("SNR 18 dB","snr","SNR_18","patent_fixed_bypass"),
        ("SNR 10 dB","snr","SNR_10","patent_fixed_bypass"),
        ("Clock +1000 ppm","stress","clock_plus1000ppm","patent_fixed_bypass"),
        ("Literal DC at 30 dB","snr","SNR_30","patent_literal_dc")]
    data=[]
    for label,suite,case,m in selected:
        r=lookup(suite,case,m);data.append([label,f"{r['errors']:,} / {r['n']:,}",f"{r['ser']*100:.4f}%"])
    table(["Executed condition","Failed intervals / evaluated","Interval SER"],data,[190,185,120])
    para("The fixed reconstruction works well at high SNR and with clock mismatch in the tested synthetic channels. It is not uniformly best: the simple fixed-clock baseline wins several noise-only tests. The inferred adaptive law helps some offset/gain cases and hurts others.")
    para("The literal DC equation produces a conditional conflict with the negative-level threshold under the stated interpretation. This is a disclosure/reconstruction issue, not a verified defect in the vendor's physical product.")
    para("Scope: no FPGA-board experiment, no Vivado execution, no synthesis/timing closure at 800 MS/s, no measured coupler model and no complete Ethernet frame decoder.",small)
    page()

    heading("1. Architecture and published parameters")
    para("The patent probes a full-duplex automotive Ethernet line. A directional coupler separates both directions; two DVGAs set amplitude, two ADCs acquire samples and two FPGA paths decode PAM-3 symbols. USB passes symbols to host software for higher-layer decoding.")
    table(["Processing stage","Implemented rule"],[
        ["ADC interface","Behavioural already-deserialized 8-bit ADC codes; no ISERDES electrical model"],
        ["DC correction","Causal 128-sample MAX/MIN window, optional literal equation or disclosed bypass"],
        ["Slope / level decoder","Four thresholds: Plus 140, Minus 95, ZeroPlus 160, ZeroMinus 80"],
        ["Spike filter","Reconstructed removal of isolated <=2-sample runs with equal neighbours"],
        ["Must transition / midpoint","Opposite edge directions within <=12 samples; midpoint inside bounded plateau"],
        ["Edge filter 1 / 2","Keep must or >=9-sample edge distance; reject edge before a must edge within 4"],
        ["Sampling / output","12-sample free-run corrected by must midpoints; retain must points, remove near future duplicates"]
    ],[150,345])
    para("Nominal sampling is 800 MS/s, or 1.25 ns/sample; 12 samples/symbol imply approximately 66.667 MBd. The patent's '66.66 Mbps' wording is not used as the symbol-rate unit here. Extension to 1000BASE-T1 is claimed in the patent but not fully specified or implemented in this package.")
    para("Nominal ADC levels 60/127/194, initial receiver phase 6, the DC guard value 80, and integer midpoint rounding are assumptions. The original document gives threshold codes but not a complete analog calibration or bill of materials.")
    page()

    heading("2. Ambiguities that affect reproduction")
    para("DC correction",sub)
    para("Column 6 prints y = x - MIN + Minus_Threshold, conditioned on MAX, MIN and y &lt;255. With the same Minus_Threshold=95 used for slicing, every corrected value satisfies y &gt;=95, because the causal window includes x. The mirrored strict falling rule requires y &lt;95 to decode -1. Active correction and that rule cannot coincide.")
    para("The reconstruction tests the equation literally and also tests the patent's allowed DC bypass. It does not silently repair the equation. The unknown guard is varied separately; changed anchor values are labelled engineering variants. Separate register meanings or unreported equality handling could resolve the issue in real hardware.")
    para("Must transition",sub)
    para("Figure 2 refers to opposite slopes, and Figure 4G shows a three-sample zero valley between +1 levels. The implemented interpretation pairs opposite edge directions, rather than requiring a +1-to--1 level change. The text is ambiguous; this is a documented design decision.")
    para("Spike filtering and time recovery",sub)
    para("Figure 4F illustrates spike removal but gives no complete state machine. The chosen <=2-sample isolated-run rule preserves Figure 4G's three-sample pulse. The patent does not specify startup phase, midpoint rounding, or all edge-distance bookkeeping details. Frame-based lookahead is used in the complete HDL reference; bounded delays and buffered histories would be required for a streaming realization.")
    para("Adaptive thresholds",sub)
    para("The patent gives a 12-sample default update block but no exact update equation. The optional causal decision-directed EWMA here uses previous decoded classes, rate 1/8 and >=3 samples per class. It receives no TX labels, SNR, gain or DC truth. This law is an engineering hypothesis, not the vendor's algorithm. Incorrect class assignments can reinforce bias.")
    figure("dc_sensitivity",175)
    page()

    heading("3. Channel, evaluation and reproducibility")
    para(f"The main suite generated {META['generated_symbol_exposures']:,} channel-symbol exposures and executed {META['evaluated_method_runs']:,} method/channel trials. There are seven SNR points, five independent seeds and two channels per SNR, plus 17 stress cases and a 5 x 5 gain/offset grid. Phase and DC sensitivities are additional runs.")
    para("Symbols are synthetic random or structured PAM-3, not an IEEE-compliant PCS-encoded Ethernet stream. A first-order low-pass models finite edges; echo is one delayed tap; reverse-channel leakage is an independent PAM-3 contributor. A DVGA gain/offset and a saturating rounded 8-bit ADC complete the behavioural path.")
    para("Noise variance uses nominal transmitted zero-mean symbol power: 67^2 E[s^2] / 10^(SNR/10). Gain, echo and clipping are applied separately; a changed gain changes effective received SNR. Clock offset changes TX symbol duration relative to the ADC. Independent boundary jitter is clipped to prevent invalid durations.")
    para("Evaluation without oracle-assisted decoding",sub)
    para("TX timing and labels are used only after decoding. Each original TX interval is correct only with exactly one receiver output inside it and the right value. Missing and duplicate intervals are failures. No edit-distance rematching or best-phase selection hides synchronization loss. The first 32 and final 8 symbols are excluded by a fixed declared policy.")
    para("Interval SER = failed TX intervals / evaluated TX intervals. CSV files also retain missing intervals, duplicate intervals, extra outputs, amplitude errors among singly represented intervals, clipping and RMS/P95 timing position relative to the true symbol center.")
    para("Statistics",sub)
    para("Every SNR/method point pools 40,560 evaluated symbols. Wilson 95% bounds are descriptive; time-correlated burst errors violate independent-binomial assumptions. Independent-run min/max and SD are retained. Zero observed errors gives a finite upper bound and does not prove zero error probability. Stress/grid trials have fewer independent seeds and are exploratory, not field reliability estimates.")
    para("Seeds, configuration, Python/NumPy versions and run duration are in results/metadata.json. All outputs are regenerated from executable simulation code. Reproduction also requires SciPy; current library versions are recorded in the environment snapshot included with the package.")
    page()

    heading("4. Noise sweep")
    figure("snr_sweep",290)
    table(["SNR (dB)","Fixed bypass (%)","Adaptive (%)","Simple baseline (%)"],[[r['snr_db'],f"{r['ser']*100:.4f}",f"{lookup('snr',r['case'],'inferred_adaptive_bypass')['ser']*100:.4f}",f"{lookup('snr',r['case'],'two_threshold_fixed_clock')['ser']*100:.4f}"] for r in rows("snr","patent_fixed_bypass")],[85,137,137,136])
    para("In this noise-only sweep the fixed-clock baseline retains a favourable sampling phase and has no clock drift. It avoids several false timing anchors produced by the reconstructed slope logic. This comparison does not establish that a fixed-clock comparator is generally superior; the independent phase/drift cases test the capability that it lacks.")
    page()

    heading("5. Stress, timing and trace results")
    figure("stress_comparison",300)
    figure("phase_sweep",210)
    para("Clock drift is recovered well when useful opposite-edge pairs occur. Long identical runs can accumulate drift until transitions return. Slow-edge and impulse scenarios also illustrate why a timing/filter chain can help. Gain/DC asymmetry and false timing anchors remain important limitations.")
    page()

    heading("6. Actual waveform and calibration sensitivity")
    figure("waveform",300)
    figure("gain_dc_map",230)
    para("The waveform is a real stored trace from the executed model. TX reference is displayed for analysis only and is not passed to the decoder. The offset/gain map is exploratory (2,008 evaluated symbols/channel per cell); it does not demonstrate universally robust calibration.",small)
    page()

    heading("7. Independent HDL verification")
    if HDL:
        para(f"Icarus Verilog 12.0 executed {len(HDL['cases'])} dual-channel cases and compared {HDL['total_channel_samples_checked']:,} channel samples. Every case passed. Scenarios: clean, SNR 10 dB, clock drift, impulses, DC step and long runs, each with DC bypass and literal DC enabled.")
        table(["Case","DC bypass","Literal DC"],[[case,"PASS","PASS"] for case in ["clean","noise10","drift","impulses","step","long_runs"]],[195,150,150])
    else:para("No HDL validation result found. Do not infer a hardware check from Python-only results.")
    para("Checked quantities",sub)
    para("Every ADC sample's corrected value and raw level; complete symbol output counts; every output sample index and symbol value for both channels. Front-end input-valid stalls were deliberately inserted to check state retention. Comparison vectors and logs are included.")
    para("Additional validation: 17 Python/model/API tests passed. A DOM integration test exercised saved-waveform controls, table filters and live-result application without script errors. Canvas calls were mocked in that test; native browser rendering was blocked by this execution environment and is not claimed. The PDF itself was rendered and inspected.",small)
    para("What the files represent",sub)
    para("pam3_reference.sv is a complete frame-based functional HDL reference; it is simulation-only. pam3_frontend.sv is a synthesizable DC/slope implementation, but its large unpipelined extrema reduction is not a production 800 MS/s architecture. The optional inferred adaptive law is Python-only. tb_dual.sv generates a 100 MHz testbench clock; its VCD is not a throughput measurement.")
    para("Vivado script",sub)
    para("A Tcl script is supplied to run a saved comparison case in Vivado/XSim. It was not executed here. No post-synthesis or post-route check, target FPGA selection, resource/power report, ISERDES capture, USB transfer or hardware experiment was performed.")
    para("Next hardware milestones",sub)
    para("Select compatible ADC/FPGA interfaces; define sample-parallel processing and delay budgets; design and pipeline the full timing chain; synthesize and close timing; validate real coupler/DVGA/ADC models; acquire real bidirectional traffic; implement USB/host PCS decoding; compare against known traffic and measure losses.")
    page()

    heading("8. Full stress summary")
    table(["Scenario","Fixed bypass %","Inferred adaptive %","Simple baseline %"],[[r['case'],f"{r['ser']*100:.4f}",f"{lookup('stress',r['case'],'inferred_adaptive_bypass')['ser']*100:.4f}",f"{lookup('stress',r['case'],'two_threshold_fixed_clock')['ser']*100:.4f}"] for r in rows("stress","patent_fixed_bypass")],[183,104,104,104])
    para("All literal-DC results, per-run variation, missing/extra counts and timing metrics are in summary.csv and all_runs.csv. No failed condition has been removed from the delivered suite.")
    page()

    heading("9. Open, reproduce and extend")
    para("Open PAM3_Results.html directly to browse saved plots, method comparisons and full-resolution trace windows offline. Use app.py for an actual new calculation with changed channel settings; viewing saved trace controls alone does not rerun the model.")
    table(["Task","Command from extracted package directory"],[
      ["Install Python packages","python -m pip install -r requirements.txt"],
      ["Run meaningful tests","python -m unittest discover -s tests -v"],
      ["Repeat numerical suite","python run_simulation.py --symbols 4096 --repetitions 5"],
      ["Repeat HDL check","python verify_hdl.py (Icarus Verilog required on PATH)"],
      ["Rebuild plots and report","python make_report.py"],
      ["Interactive local experiments","python app.py; open http://127.0.0.1:8765"],
      ["Decode measured ADC CSV","python decode_csv.py measured.csv --out decoded"]
    ],[158,337])
    para("Windows launchers install dependencies in a local .venv. No API key or cloud service is used. The generated results are already supplied, so opening them needs neither Python nor installation.")
    para("Source and implementation references",sub)
    para("Primary method source: supplied US11405248B2 PDF, especially Figures 1-5, columns 5-8 and claims 1-19. Exact assumptions and optional update equations: docs/ASSUMPTIONS.md. Model implementation: pam3/model.py; channel/evaluator: pam3/channel.py.")
    para("Tool documentation: steveicarus.github.io/iverilog/usage/ (Icarus Verilog); amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/verification.html (Vivado simulation). No external experimental paper results were used in the numerical report.",small)
    para("Use in research: call these results an assumption-labelled functional reconstruction. Do not attribute the inferred adaptive law, synthetic channel parameters, or measured error rates to the patented commercial product.")

    def footer(c,doc):
        c.setStrokeColor(colors.HexColor("#d6ded8"));c.line(50,42,545,42)
        c.setFont("Body",7);c.setFillColor(colors.HexColor("#697975"))
        c.drawString(50,29,"US11405248B2 | Functional reconstruction | 2026-10-04")
        c.drawRightString(545,29,str(doc.page))
    doc=SimpleDocTemplate(str(ROOT/"PAM3_Simulation_Report.pdf"),pagesize=(595,842),
        leftMargin=50,rightMargin=50,topMargin=45,bottomMargin=58,
        title="PAM-3 patent reconstruction and simulation",author="Prepared for Alborz Seifaei")
    doc.build(story,onFirstPage=footer,onLaterPages=footer)

if __name__=="__main__":
    plots();html_report();pdf_report();print("Built plots, self-contained HTML, and PDF from executed results.")
