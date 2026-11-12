#!/usr/bin/env python3
"""Generate an English technical PDF and Persian self-contained HTML handover."""
import html,json,platform
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
ROOT=Path(__file__).resolve().parent

def load():
    read=lambda p:json.loads((ROOT/p).read_text())
    v=read('results/verification/validation.json');i=read('results/interfaces/validation.json');s=read('results/structure/validation.json')
    syn=[read(f'results/synthesis/L{n}_DC0_A0/summary.json') for n in [1,8]]
    post=[read(f'results/post_synthesis/L{n}_DC0_A0/validation.json') for n in [1,8]]
    assert all(x.get('all_passed',False) for x in [v,i,s])
    assert all(x['check_passed'] for x in syn) and all(x['passed'] for x in post)
    return v,i,s,syn,post

def pdf_report(v,interfaces,structure,syn,post):
    font=Path('/usr/share/fonts/truetype/dejavu')
    for name,file in [('DV','DejaVuSans.ttf'),('DV-Bold','DejaVuSans-Bold.ttf'),('Mono','DejaVuSansMono.ttf')]:
        pdfmetrics.registerFont(TTFont(name,str(font/file)))
    pdfmetrics.registerFontFamily('DV',normal='DV',bold='DV-Bold',italic='DV',boldItalic='DV-Bold')
    ink=colors.HexColor('#173548');accent=colors.HexColor('#137d75');light=colors.HexColor('#eef4f4')
    styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name='BodyX',fontName='DV',fontSize=9.4,leading=14,textColor=ink,spaceAfter=9))
    styles.add(ParagraphStyle(name='H1X',fontName='DV-Bold',fontSize=18,leading=24,textColor=ink,spaceAfter=14))
    styles.add(ParagraphStyle(name='H2X',fontName='DV-Bold',fontSize=11,leading=16,textColor=accent,spaceBefore=10,spaceAfter=7))
    styles.add(ParagraphStyle(name='SmallX',fontName='DV',fontSize=8.1,leading=11,textColor=ink,spaceAfter=5))
    styles.add(ParagraphStyle(name='CodeX',fontName='Mono',fontSize=7.6,leading=11,textColor=ink,backColor=light,borderPadding=9,spaceAfter=10))
    story=[]
    def p(text,style='BodyX'):story.append(Paragraph(text,styles[style]))
    def h(text):p(text,'H2X')
    def title(num,text):p(f'{num:02d} / {text}','H1X')
    def code(text):p(html.escape(text).replace(' ','&#160;').replace('\n','<br/>'),'CodeX')
    def table(rows,widths):
        cells=[[Paragraph(html.escape(str(c)),styles['SmallX']) for c in row] for row in rows]
        t=Table(cells,colWidths=widths,repeatRows=1,hAlign='LEFT')
        t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),light),('LINEBELOW',(0,0),(-1,0),.8,accent),
            ('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#d7e2e4')),('VALIGN',(0,0),(-1,-1),'TOP'),
            ('LEFTPADDING',(0,0),(-1,-1),7),('RIGHTPADDING',(0,0),(-1,-1),7),
            ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
        story.append(t);story.append(Spacer(1,10))
    def page():story.append(PageBreak())
    title(1,'Digital implementation delivered')
    p('<b>US11405248B2 - FPGA based system for decoding PAM-3 signals</b>')
    p('A complete portable, bounded-memory digital reconstruction from two deserialized 8-bit ADC streams to channel-tagged PAM3 host records. Created 4 October 2026. The supplied 19-page patent is included and the reconstruction choices are explicit.')
    table([['Measured verification','Result'],
        ['RTL configurations / actual executions','8 / 16 - all passed'],
        ['Core + paired analyzer sample checks',f"{v['core_sample_checks']+v['analyzer_channel_sample_checks']:,}"],
        ['Exact output symbol comparisons',f"{v['total_symbols_checked']:,}"],
        ['Channel-capture test instances',f"{v['total_channel_frames']:,}"],
        ['XC7 mapped-netlist simulations',f"Both passed; {sum(x['channel_samples_checked'] for x in post):,} channel samples"],
        ['Hardware latches after optimization','0 in checked configurations']], [267,238])
    h('Implemented boundary')
    p('RTL includes literal optional DC correction, slope slicing, spike removal, both edge filters, sampling-point reconstruction/filtering, symbol extraction, dual-channel synchronization, sparse symbol packing, a registered host arbiter, and a separate overflow-reporting capture FIFO. Python parses the binary host record stream.')
    h('Physical work still required')
    p('No board-specific ADC PHY/clock-domain crossing, coupler/DVGA circuit, USB/DMA controller, Ethernet PCS decoder or board bitstream is included. Vivado was not available. Yosys mapping and functional simulation do not establish 800 MS/s timing, power or real-channel accuracy.')
    p('Primary source: supplied source_patent.pdf, US 11,405,248 B2, granted 2 August 2022; figures 1-4 and printed columns 5-8. File/figure interpretations: docs/PATENT_ASSUMPTIONS.md.','SmallX')
    page();title(2,'Streaming architecture')
    table([['Stage','Bounded state / role'],
        ['ADC / slope','Previous ADC and decoded level; optional 127-byte causal history'],
        ['Spike filter','Five original level positions plus boundary-valid bits'],
        ['Edges / anchors','Previous edge and direction; four pending edges; 32-bit anchor ring'],
        ['Sampling / symbol','32-entry level ring; four candidate and essential bits; 64-bit indices'],
        ['Per-channel packer','32+LANES two-bit symbols plus one output record register'],
        ['Host output','Round-robin arbitration, one 128-bit registered record']], [145,360])
    h('Why the lookahead is 20 sample positions')
    p('Filtered position t-2 uses two future raw levels. A must midpoint is at most seven positions before its right edge; the second edge filter needs four more positions. The anchor is known within 13 input positions after that midpoint. Candidate evaluation at t-16 leaves margin. The final four-position candidate filter emits the selected point at t-20.')
    p('A 32-entry filtered-level ring is sufficient: a final symbol read occurs 18 positions after the filtered value was written, before reuse. Total memory does not grow with capture length. The optional DC window remains fixed at 128 samples.')
    h('Lanes and stalls')
    p('LANES=1 or 8 advances consecutive real samples in chronological order. Eight lanes unroll dependent logic in a single clock; this is not an eight-stage clock pipeline. A blocked output freezes sample-time. Paired input transfers occur only when both channels are ready, while decisions and outputs remain independent.')
    h('Capture termination')
    p('A final ADC beat schedules 20 invalid virtual positions to flush boundary decisions. These do not update ADC/DC/adaptive state. The terminal output must be accepted before history is reset and the capture ID increments. Empty captures still have a terminal record. With no terminal beat, processing runs continuously.')
    page();title(3,'Patent semantics and assumptions')
    table([['Element','Delivered interpretation'],
        ['Four thresholds','Plus=140, Minus=95, ZeroPlus=160, ZeroMinus=80'],
        ['Rising/falling','Strict comparisons; equality or constant ADC holds the previous level'],
        ['Spike','Fill isolated original runs of width 1 or 2 only when neighbours agree'],
        ['Must transition','Opposite consecutive edge directions, separated by <=12 samples'],
        ['Must midpoint','floor((left_edge+right_edge-1)/2), inside the intervening plateau'],
        ['First edge filter','Must edge or >=9 samples from preceding raw edge; first edge retained'],
        ['Second edge filter','Drop edge if a must edge appears within the next four positions'],
        ['Sampling','Start phase 6, step 12, restart at retained must midpoint'],
        ['Candidate filter','Keep essential points; drop a nonessential point if another is <=4 later']], [135,370])
    h('Literal DC ambiguity preserved')
    p('The printed correction is y=x-MIN+95, with widened arithmetic and strict y&lt;255 gate. Because the causal window includes x, y is at least 95 when correction is active. The interpreted falling decision for -1 requires y&lt;95. These conditions cannot coincide while correction is active. The patent does not resolve the threshold naming/equality ambiguity; the disclosed bypass mode is therefore the default. The literal mode remains implemented and tested.')
    h('Adaptive option is an engineering reconstruction')
    p('Q8 integer means start at 60/127/194. Completed 12-sample blocks update classes with at least three samples, using a 1/8 EWMA and floor arithmetic. Threshold ratios are 13/67, 32/67, 33/67 and 47/67, followed by half-up rounding and clamping. No transmitter labels or fitted transmitter phase enter the decoder. This is not an undisclosed vendor algorithm; it also differs in rounding from the earlier floating-point simulation.')
    p('Detailed source mapping: source_patent.pdf columns 5-6 (ADC/DC/slicing), column 7 and figures 2/4F/4G (spikes and edges), columns 7-8 (sampling), figure 1/column 8 (host boundary).','SmallX')
    page();title(4,'Actual RTL verification')
    rows=[['Lanes','DC','Adapt Q8','Core symbols','Host symbols','Result']]
    for r in v['configurations']:rows.append([r['lanes'],int(r['dc_enabled']),int(r['adaptive_q8']),r['core']['symbols_checked'],r['analyzer']['symbols_checked'],'PASS'])
    table(rows,[48,40,73,112,123,109])
    p(f"Each configuration tested {v['configurations'][0]['frames_per_channel']} captures per channel. Total core checks: {v['core_sample_checks']:,}; dual-analyzer channel sample checks: {v['analyzer_channel_sample_checks']:,}. These are repeated sample exposures across builds, not that many independent physical measurements.")
    h('What was checked')
    p('Every corrected ADC code, raw decoded level and spike-filtered level; every selected output index and symbol; exact symbol counts, terminal captures, and stable payloads under backpressure. The integrated analyzer records are parsed and compared per channel/capture. The oracle uses independent offline run/edge/candidate lists rather than RTL pipeline state.')
    h('Input coverage')
    p('Empty and 1-33-sample tails; constant ADC codes including exact thresholds and extremes; strict-threshold sequences; ramps; long runs; one/two/three-sample pulses; random lengths around 128/256/1024 boundaries; and synthetic PAM3 at three noise settings. Partial vectors also occur inside captures. Random input bubbles, random sink stops and 180-clock output-stop bursts exercise finite buffering.')
    h('Interface and structural checks')
    p('Capture FIFO: 6,000 clocks, 2,606 ordered read checks and 1,940 explicitly counted drops. Core protocol test: malformed counts, reset and empty/tiny intervals; 100 consecutive eight-sample beats accepted with a ready sink. Eight Python parser tests cover legal records and malformed/truncated captures. All eight RTL parameterizations and the capture FIFO passed lowered-netlist connectivity/no-latch checks.')
    p('Evidence: results/verification/validation.json, results/interfaces/validation.json and results/structure/validation.json. Simulation suite: Icarus Verilog 12.0; Python '+platform.python_version()+'.','SmallX')
    page();title(5,'Synthesis and mapped-circuit checks')
    rows=[['Digital two-channel top','LUT cells','FF cells','CARRY4','Mapped cells']]
    for r in syn:rows.append([r['configuration'],f"{r['LUT_cells']:,}",f"{r['FF_cells']:,}",f"{r['cell_counts'].get('CARRY4',0):,}",f"{r['total_cells']:,}"])
    table(rows,[163,86,86,85,85])
    p('Tool: '+html.escape(syn[0]['tool'])+'. Target family: generic Xilinx 7-series (XC7), with I/O/clock buffer insertion disabled. Counts include both decoder channels, both packers and host mux. The separate capture FIFO is not part of these counts. LUT cells are counted primitives, not a device occupancy or post-route slice estimate.')
    h('Flow and actual circuit simulation')
    p('The synth_xilinx flow omits optional SAT resource sharing. Explicit signed PAM3 and control-state encodings prevent automatic FSM extraction from enumerating a large unrolled input table. Check assertions passed with no optimized hardware latches. Mapped Verilog and EDIF are included.')
    table([['Mapped configuration','Channel samples','Symbols','Result']]+[[r['configuration'],f"{r['channel_samples_checked']:,}",f"{r['symbols_checked']:,}",'PASS'] for r in post],[175,120,110,100])
    p('Both mapped circuits were executed with the XC7 functional primitive library and independently generated inputs, including output stalls. These are functional netlist tests without timing delays. Structural checks cover DC/adaptive options; only the fixed/DC-bypass 1- and 8-lane tops are technology-mapped in this delivery.')
    h('No timing claim')
    p('The 100 MHz clock / eight-lane setting corresponds arithmetically to an 800 MS/s input target. It is not measured or guaranteed. Eight-lane dependencies, window extrema and optional constant divisions can create long paths. Vivado synthesis/place/route and WNS/TNS review on the selected part remain required. No board or physical USB throughput was measured.')
    page();title(6,'Host records and capture integrity')
    table([['Bits','Field'],['63:0','Up to 32 two-bit symbols, earliest at bits 1:0'],['70:64','Valid count, 0..32'],['71','Channel 0=A/master, 1=B/slave'],['72','Terminal record of this channel capture'],['104:73','32-bit capture ID, initially zero'],['127:105','Reserved zero']], [95,410])
    p('Codes: 11=-1, 00=0, 01=+1; 10 is illegal. Unused payload bits are zero. Binary files contain 16 little-endian bytes per record. A zero-count record is legal only at capture end. Compact records retain symbol order, not sample indices; the direct core interface retains exact 64-bit indices.')
    code('python3 host_decode.py results/example_host_records.bin \\\n  --csv results/example_decoded_symbols.csv \\\n  --summary results/example_decoded_summary.json')
    h('Capture buffer and losses')
    p('The optional FIFO is single-clock, depth 2^LOG_DEPTH beats. Defaults give 256 paired eight-sample beats (2,048 samples/channel). Full-buffer arrivals that cannot be stored set a sticky overflow and increment a saturating dropped-beat counter. Any such loss invalidates the affected acquisition: reset/restart rather than interpreting it as continuous. A multi-clock ADC requires a separate verified asynchronous FIFO.')
    h('Bandwidth arithmetic')
    p('At nominal 66.667 MBd, two channels of two-bit symbols carry about 33.333 MB/s. Full 128-bit records for 32 symbols require about 66.667 MB/s before transport overhead. Short captures add overhead. The two-channel 8-bit 800 MS/s raw boundary is 1.6 GB/s. These budgets assume nominal symbol cadence and are not throughput measurements.')
    page();title(7,'Vivado and physical integration')
    p('The scripts are ready for use with an installed Vivado and an actual device. The default xc7a200tfbg484-2 is only an example part. No pin locations are invented. The OOC example constrains a 10 ns clock and abstract 2 ns input/output delays; these are not ADC LVDS timing constraints.')
    code('vivado -mode batch -source vivado/create_project.tcl \\\n  -tclargs xc7a200tfbg484-2 8 0 0\n\nvivado -mode batch -source vivado/synth_ooc.tcl \\\n  -tclargs xc7a200tfbg484-2 8 0 0 1')
    table([['Next physical milestone','Acceptance evidence'],
        ['Choose board / ADC / analog parts','Datasheets, channel range, parallel output width and clock plan'],
        ['ADC PHY and CDC','Vendor capture/deserialization, pin/I/O constraints, timing and continuity checks'],
        ['Implementation timing','Placed/routed WNS/TNS, constrained-path coverage and resource review'],
        ['Transport adapter','Byte-correct 128-bit records, sustained bandwidth and overflow handling'],
        ['Analog calibration','Known PAM3 patterns and measured gain/DC/noise/channel separation'],
        ['Protocol layer if required','PCS/descrambler and Ethernet decoding against valid known frames']], [181,324])
    p('Capture intervals are not Ethernet packets. The patent gives a host protocol-analysis boundary, not enough detail to reconstruct a vendor USB driver or complete Ethernet PCS. These physical and protocol modules require explicit component/standard selections and real-device testing.')
    page();title(8,'Reproduction and deliverable map')
    code('python3 -m pip install -r requirements.txt\npython3 verify_hdl.py\npython3 verify_interfaces.py\npython3 check_structure.py --yosys yosys\npython3 run_synthesis.py --lanes 8\npython3 verify_netlist.py --lanes 8 \\\n  --cells /usr/share/yosys/xilinx/cells_sim.v')
    table([['Path','Purpose'],['rtl/','Six portable synthesizable SystemVerilog modules'],['reference/','Numerical fixed model and integer adaptive oracle'],['tests/','Core, analyzer, FIFO and protocol testbenches; parser tests'],['host_decode.py','Binary record parser and CSV export'],['vivado/','Project/OOC scripts and example constraints'],['results/','Actual validation logs, mapping statistics, mapped circuits and example capture'],['docs/','Architecture, interfaces, reconstruction assumptions and supplied patent'],['README_FA.md','Persian startup/integration guide'],['SHA256SUMS.txt','Included-file integrity checks']], [155,350])
    h('Interpretation of a passing result')
    p('The delivered digital reconstruction has repeatable exact equivalence tests and actual synthesis artifacts. Passing tests establish agreement for the stated inputs and implemented semantics. They do not prove undisclosed vendor semantics, all possible inputs, a physical sample clock, real-channel SER or an automotive analyzer certification.')
    p('The existing functional simulation package remains a separate earlier milestone. This delivery adds the complete streaming digital core and host path. Review the documented literal-DC ambiguity and the integer adaptive update before changing thresholds or integrating a real ADC.')
    def footer(c,doc):
        c.setStrokeColor(colors.HexColor('#d7e2e4'));c.line(45,44,550,44)
        c.setFont('DV',7.5);c.setFillColor(ink);c.drawString(45,31,'US11405248B2 | Digital reconstruction | 2026-10-04')
        c.drawRightString(550,31,str(doc.page))
    path=ROOT/'PAM3_FPGA_Implementation_Report.pdf'
    SimpleDocTemplate(str(path),pagesize=A4,rightMargin=45,leftMargin=45,topMargin=43,bottomMargin=58,
        title='US11405248B2 Streaming Digital Implementation',author='Digital reconstruction and verification').build(story,onFirstPage=footer,onLaterPages=footer)
    return path

def html_report(v,interfaces,structure,syn,post):
    n=v['core_sample_checks']+v['analyzer_channel_sample_checks']
    rows=''.join(f"<tr><td>{r['lanes']}</td><td>{int(r['dc_enabled'])}</td><td>{int(r['adaptive_q8'])}</td><td>{r['core']['symbols_checked']:,}</td><td>{r['analyzer']['symbols_checked']:,}</td><td class='ok'>قبول</td></tr>" for r in v['configurations'])
    mapping=''.join(f"<tr><td dir='ltr'>{r['configuration']}</td><td>{r['LUT_cells']:,}</td><td>{r['FF_cells']:,}</td><td>{r['cell_counts'].get('CARRY4',0):,}</td><td class='ok'>قبول</td></tr>" for r in syn)
    gate=''.join(f"<tr><td dir='ltr'>{r['configuration']}</td><td>{r['channel_samples_checked']:,}</td><td>{r['symbols_checked']:,}</td><td class='ok'>قبول</td></tr>" for r in post)
    text=f'''<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>تحویل پیاده‌سازی دیجیتال PAM3</title>
<style>*{{box-sizing:border-box}}body{{margin:0;background:#eef3f5;color:#173548;font:16px/1.95 Tahoma,Arial,sans-serif}}main{{max-width:1050px;margin:38px auto;padding:0 24px}}header,section{{background:white;border:1px solid #d7e2e4;border-radius:14px;padding:25px 30px;margin-bottom:20px}}h1{{font-size:29px;line-height:1.55;margin:10px 0}}h2{{font-size:21px;margin:0 0 14px;color:#137d75}}p{{margin:8px 0 15px}}.tag{{font-size:13px;color:#137d75;letter-spacing:.4px}}.stats{{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin:22px 0}}.stat{{background:#eff6f5;border-radius:10px;padding:16px}}.stat b{{display:block;font-size:26px;color:#137d75}}.stat span{{font-size:13px}}.limit{{border-right:4px solid #b97826;background:#fff7e9;padding:15px 20px;border-radius:7px}}table{{width:100%;border-collapse:collapse;font-size:14px;margin:18px 0}}th,td{{padding:10px;text-align:right;border-bottom:1px solid #d7e2e4}}th{{background:#edf4f4}}.ok{{color:#137d75;font-weight:bold}}code,pre{{font-family:Consolas,monospace;direction:ltr;text-align:left}}pre{{overflow:auto;font-size:13px;line-height:1.7;background:#102b3d;color:#e5f3f2;padding:17px;border-radius:9px;white-space:pre}}.files td:first-child{{direction:ltr;text-align:left;font-family:Consolas,monospace}}.scroll{{overflow:auto}}footer{{font-size:12px;color:#5d707b;padding:10px 20px 30px}}@media(max-width:640px){{main{{padding:0 12px;margin:16px auto}}header,section{{padding:20px 17px}}.stats{{grid-template-columns:1fr}}h1{{font-size:24px}}}}@media print{{body{{background:white}}main{{margin:0;max-width:none}}header,section{{break-inside:avoid}}pre{{white-space:pre-wrap}}}}</style></head><body><main>
<header><div class="tag">تحویل مهندسی • ۴ اکتبر ۲۰۲۶ • US11405248B2</div><h1>پیاده‌سازی دیجیتال پیوسته پتنت PAM3</h1><p>هسته دوکاناله از نمونه‌های هشت‌بیتی ADC تا خروجی نمادهای قابل خواندن در کامپیوتر پیاده‌سازی، آزمایش و برای خانواده Xilinx 7-series سنتز شد.</p>
<div class="stats"><div class="stat"><b>{v['total_symbols_checked']:,}</b><span>نماد خروجی تطبیق‌داده‌شده در RTL</span></div><div class="stat"><b>{n:,}</b><span>پردازش نمونه در آزمون‌های RTL</span></div><div class="stat"><b>۱۶ / ۱۶</b><span>اجرای RTL قبول‌شده</span></div></div>
<div class="limit">برد واقعی، ADC و USB فیزیکی، بیت‌استریم و زمان‌بندی Vivado اجرا نشده‌اند. سرعت ۸۰۰ MS/s هدف ورودی است و هنوز روی برد تأیید نشده است.</div></header>
<section><h2>چه چیزی تحویل داده شده؟</h2><p>DC اختیاری، تشخیص سطح از شیب، حذف ضربه، تشخیص و دو فیلتر لبه، تولید و فیلتر نقطه برداشت، استخراج نماد، پردازش مستقل دو کانال، بسته‌بندی و داوری خروجی میزبان، بافر اختیاری با تشخیص سرریز و برنامه تبدیل رکورد به CSV. حافظه هسته محدود است و به طول دریافت وابسته نیست.</p><p>در هر کلاک یک یا هشت نمونه پذیرفته می‌شود. تصمیم نقطه برداشت با ۲۰ موقعیت نمونه تأخیر آماده می‌شود؛ توقف رابط و انتظار برای کامل شدن بسته خروجی، زمان واقعی را افزایش می‌دهد.</p><p>داده تطبیقی با حساب صحیح Q8 هم موجود است. این قانون تغییر آستانه، بازسازی مهندسی است؛ پتنت معادله دقیق آن را افشا نکرده است.</p></section>
<section><h2>نتیجه آزمون‌های واقعی</h2><p>در هر تنظیم، ۶۰ بازه دریافت شامل انتهای کوتاه، کدهای ثابت، مرز آستانه، رمپ، داده تصادفی، ضربه و PAM3 نویزی بررسی شد. هر نمونه اصلاح‌شده، سطح خام، سطح فیلترشده، اندیس برداشت و نماد مقایسه شد. مسیر میزبان نیز برای هر کانال بازخوانی شد. تعدادها شامل تکرار داده برای تنظیم‌ها و مسیرهای آزمون هستند.</p><div class="scroll"><table><thead><tr><th>نمونه/کلاک</th><th>DC</th><th>تطبیقی</th><th>نماد هسته</th><th>نماد میزبان</th><th>وضعیت</th></tr></thead><tbody>{rows}</tbody></table></div><p>توقف تصادفی ورودی و خروجی، توقف خروجی برای ۱۸۰ کلاک، بردارهای ناقص، ریست و بازه خالی آزمایش شدند. بافر در ۶٬۰۰۰ کلاک، ۲٬۶۰۶ خروجی مرتب و ۱٬۹۴۰ رخداد حذف ناشی از پرشدن را درست ثبت کرد. ۸ آزمون خواندن رکورد نیز قبول شدند.</p></section>
<section><h2>سنتز و بررسی مدار خروجی</h2><p>این اعداد برای کل هسته دوکاناله با آستانه ثابت و DC خاموش هستند. بافر اختیاری جداگانه در این شمارش نیست. ابزار: Yosys 0.33؛ خانواده هدف: XC7؛ قرارگیری و مسیریابی انجام نشده است.</p><table><tr><th>تنظیم</th><th>LUT</th><th>فلیپ‌فلاپ</th><th>CARRY4</th><th>ساختار</th></tr>{mapping}</table><p>مدارهای حاصل از سنتز با کتابخانه عملکردی Xilinx هم اجرا و با مرجع مستقل مقایسه شدند:</p><table><tr><th>تنظیم مدار</th><th>نمونه کانال</th><th>نماد</th><th>وضعیت</th></tr>{gate}</table><p>هر هشت حالت RTL و بافر جداگانه از بررسی ساختاری و نبود لَچ پس از بهینه‌سازی گذشتند. گزینه‌های DC و تطبیقی در RTL آزمایش و بررسی ساختاری شده‌اند؛ نگاشت فناوری این تحویل برای دو حالت ثابت جدول بالاست.</p></section>
<section><h2>شروع استفاده</h2><p>پس از باز کردن ZIP، دستورها را داخل پوشه پروژه اجرا کنید. برای اجرای آزمون RTL، Icarus Verilog نیز لازم است.</p><pre>python3 -m pip install -r requirements.txt
python3 verify_hdl.py
python3 verify_interfaces.py</pre><p>خروجی نمونه آماده را بدون برد به CSV تبدیل کنید:</p><pre>python3 host_decode.py results/example_host_records.bin \\
  --csv results/example_decoded_symbols.csv \\
  --summary results/example_decoded_summary.json</pre><p>هر ردیف، کانال، بازه دریافت، ترتیب نماد و مقدار −۱/۰/+۱ را دارد. این خروجی هنوز فریم Ethernet نیست.</p><p>ساخت پروژه و سنتز/مسیریابی هسته در Vivado:</p><pre>vivado -mode batch -source vivado/create_project.tcl \\
  -tclargs xc7a200tfbg484-2 8 0 0

vivado -mode batch -source vivado/synth_ooc.tcl \\
  -tclargs xc7a200tfbg484-2 8 0 0 1</pre><p>قطعه FPGA در این دستور فقط مثال است؛ باید با قطعه برد واقعی عوض شود. قید ۱۰۰ MHz نیز هدف بررسی است و باید گزارش WNS/TNS و مسیرهای بدون قید روی همان قطعه بررسی شوند.</p></section>
<section><h2>مرز ورودی و خروجی</h2><p>ورودی هسته دو بردار نمونه هشت‌بیتی است؛ قدیمی‌ترین نمونه در هشت بیت کم‌ارزش قرار دارد. تعداد نمونه معتبر و علامت انتهای بازه نیز همراه ورودی هستند. انتقال فقط وقتی valid و ready هر دو فعال باشند انجام می‌شود. پایان بازه، تاریخچه گیرنده را برای بازه بعدی بازنشانی می‌کند؛ پایان بازه به‌معنای پایان بسته Ethernet نیست.</p><p>رکورد خروجی ۱۲۸ بیت است: ۶۴ بیت نماد، ۷ بیت تعداد معتبر، یک بیت کانال، یک بیت پایان، ۳۲ بیت شناسه بازه و ۲۳ بیت صفر رزرو. هر نماد دو بیت است: 11 برای −۱، 00 برای صفر و 01 برای +۱. فایل دودویی در هر رکورد ۱۶ بایت little-endian دارد.</p><p>اگر بافر سرریز کند، دریافت ناقص باید نامعتبر تلقی و دوباره شروع شود. بافر تک‌کلاکی همراه بسته، جایگزین FIFO عبور بین دو دامنه کلاک نیست.</p></section>
<section><h2>ابهام مهم در متن پتنت</h2><p>رابطه DC چاپ‌شده وقتی فعال باشد، مقدار اصلاح‌شده را حداقل به ۹۵ می‌رساند؛ شرط تشخیص سطح منفی در بازسازیِ قاعده شیب، کمتر از ۹۵ است. پتنت تفاوت نام رجیسترها یا رفتار مرز مساوی را روشن نمی‌کند. حالت لفظی حفظ و آزمایش شده است؛ پیش‌فرض از bypass مجاز پتنت استفاده می‌کند. این موضوع در سند فرض‌ها کامل توضیح داده شده است.</p></section>
<section><h2>نقشه فایل‌های تحویل</h2><table class="files"><tr><th>مسیر</th><th>کاربرد</th></tr><tr><td>README_FA.md</td><td>راهنمای فارسی اجرای پروژه</td></tr><tr><td>rtl/</td><td>شش ماژول کامل SystemVerilog</td></tr><tr><td>reference/</td><td>مدل مستقل ثابت و صحیح تطبیقی</td></tr><tr><td>host_decode.py</td><td>خواندن خروجی و تولید CSV</td></tr><tr><td>vivado/</td><td>پروژه، سنتز و قیدهای نمونه</td></tr><tr><td>results/</td><td>نتایج واقعی، مدار سنتزشده، لاگ و خروجی نمونه</td></tr><tr><td>docs/</td><td>معماری، رابط‌ها، فرض‌ها و پتنت کامل</td></tr><tr><td>PAM3_FPGA_Implementation_Report.pdf</td><td>گزارش فنی انگلیسی با نتایج دقیق</td></tr></table><p>قدم فیزیکی بعدی: انتخاب برد و ADC/مدار آنالوگ، رابط دریافت و کلاک، تأیید زمان‌بندی، انتقال به کامپیوتر و کالیبراسیون با سیگنال واقعی. لایه PCS و تحلیل فریم Ethernet در صورت نیاز، مرحله جداگانه است.</p></section>
<footer>نتیجه‌ها از فایل‌های JSON همین پروژه تولید شده‌اند. تطبیق دیجیتال، اثبات عملکرد کانال واقعی یا انطباق با جزئیات منتشرنشده محصول اصلی نیست. این صفحه بدون اینترنت قابل خواندن است.</footer></main></body></html>'''
    path=ROOT/'PAM3_FPGA_Handover_FA.html';path.write_text(text);return path

if __name__=='__main__':
    v,i,s,syn,post=load();print(pdf_report(v,i,s,syn,post));print(html_report(v,i,s,syn,post))
