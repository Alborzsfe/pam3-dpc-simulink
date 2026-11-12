// DOM integration fallback. Canvas calls are mocked: this is NOT a visual check.
const {JSDOM,VirtualConsole}=require(process.env.JSDOM_MODULE||'jsdom');
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');const source=fs.readFileSync(path.join(root,'PAM3_Results.html'),'utf8');
const response=JSON.parse(fs.readFileSync(path.join(root,'results/ui_test_api.json'),'utf8'));
const report={offline:false,controls:false,table:false,live_dom:false,canvas_mocked:true,
 actual_browser_rendered:false,errors:[],canvas_draw_calls:0};
function make(url){
 const vc=new VirtualConsole();vc.on('jsdomError',e=>report.errors.push(e.message));
 return new JSDOM(source,{url,runScripts:'dangerously',pretendToBeVisual:true,virtualConsole:vc,
  beforeParse(w){
   Object.defineProperty(w.HTMLCanvasElement.prototype,'clientWidth',{get:()=>1000});
   Object.defineProperty(w.HTMLCanvasElement.prototype,'clientHeight',{get:()=>405});
   const ctx={};for(const k of ['scale','fillRect','beginPath','moveTo','lineTo','stroke','fillText','setLineDash','arc','fill'])ctx[k]=()=>{report.canvas_draw_calls++};
   w.HTMLCanvasElement.prototype.getContext=()=>ctx;
   w.fetch=async(url,opt)=>{assert.equal(url,'/api/simulate');assert.deepEqual(JSON.parse(opt.body),response.parameters);return {ok:true,json:async()=>response}};
   w.URL.createObjectURL=()=> 'blob:dom-test';w.URL.revokeObjectURL=()=>{};w.HTMLAnchorElement.prototype.click=()=>{};
  }});
}
(async()=>{
 const dom=make('file:///PAM3_Results.html'),w=dom.window,d=w.document;
 assert.equal(d.querySelector('#nRuns').textContent,'516');assert.equal(d.querySelector('#nTests').textContent,'12');
 assert(d.querySelector('#simulate').disabled);assert.equal(d.querySelectorAll('#resultsTable tr').length,28);report.offline=true;
 function change(id,value){const el=d.getElementById(id);el.value=value;el.dispatchEvent(new w.Event('change'))}
 change('scenario','clock_plus1000ppm');change('channel','slave');change('method','patent_literal_dc');
 change('segment','middle');change('width','768');
 const off=d.getElementById('offset');off.value='120';off.dispatchEvent(new w.Event('input'));
 assert(report.canvas_draw_calls>100);report.controls=true;
 change('suite','stress');assert.equal(d.querySelectorAll('#resultsTable tr').length,68);
 change('tableMethod','patent_fixed_bypass');assert.equal(d.querySelectorAll('#resultsTable tr').length,17);
 const search=d.getElementById('search');search.value='clock';search.dispatchEvent(new w.Event('input'));
 assert.equal(d.querySelectorAll('#resultsTable tr').length,3);d.getElementById('downloadCsv').onclick();report.table=true;dom.window.close();
 const live=make('http://127.0.0.1:8765');const ld=live.window.document;
 for(const [id,v] of Object.entries({liveN:512,liveSnr:25,liveGain:.8,liveDc:8,liveClock:1000,liveJitter:0,liveSeed:12345}))ld.getElementById(id).value=v;
 await ld.getElementById('simulate').onclick();
 assert.equal(ld.getElementById('scenario').value,'custom');assert.equal(ld.querySelectorAll('#liveResults tbody tr').length,8);
 assert(!ld.getElementById('downloadLive').disabled);ld.getElementById('downloadLive').onclick();report.live_dom=true;live.window.close();
 assert.deepEqual(report.errors,[]);
 fs.writeFileSync(path.join(root,'results/dom_validation.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
