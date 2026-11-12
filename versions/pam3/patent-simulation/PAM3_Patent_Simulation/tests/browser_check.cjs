// Optional browser verification; not required to run the simulation package.
// npm install playwright; CHROME_PATH may point to an installed Chrome binary.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {spawn}=require('child_process');
const fs=require('fs');const path=require('path');const assert=require('assert');
const root=path.resolve(__dirname,'..');
(async()=>{
 const report={offline:false,controls:false,table:false,live:false,mobile:false,errors:[]};
 const browser=await chromium.launch({executablePath:process.env.CHROME_PATH||undefined,
   headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 let server;
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  page.on('pageerror',e=>report.errors.push(e.message));
  await page.goto('file://'+path.join(root,'PAM3_Results.html'),{waitUntil:'load'});
  assert.equal(await page.locator('#nRuns').textContent(),'516');
  assert.equal(await page.locator('#nTests').textContent(),'12');
  assert(await page.locator('#simulate').isDisabled());
  assert.equal(await page.locator('#resultsTable tr').count(),28);
  await page.screenshot({path:path.join(root,'results','dashboard_desktop.png')});
  report.offline=true;
  await page.locator('#scenario').selectOption('clock_plus1000ppm');
  await page.locator('#channel').selectOption('slave');
  await page.locator('#method').selectOption('patent_literal_dc');
  await page.locator('#segment').selectOption('middle');
  await page.locator('#width').selectOption('768');
  await page.locator('#offset').evaluate(e=>{e.value='120';e.dispatchEvent(new Event('input'))});
  await page.locator('#wave').screenshot({path:path.join(root,'results','waveform_interface.png')});
  report.controls=true;
  await page.locator('#suite').selectOption('stress');
  assert.equal(await page.locator('#resultsTable tr').count(),68);
  await page.locator('#tableMethod').selectOption('patent_fixed_bypass');
  assert.equal(await page.locator('#resultsTable tr').count(),17);
  await page.locator('#search').fill('clock');
  assert.equal(await page.locator('#resultsTable tr').count(),3);
  report.table=true;
  const mobile=await browser.newPage({viewport:{width:390,height:844}});
  mobile.on('pageerror',e=>report.errors.push('mobile: '+e.message));
  await mobile.goto('file://'+path.join(root,'PAM3_Results.html'),{waitUntil:'load'});
  assert(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await mobile.screenshot({path:path.join(root,'results','dashboard_mobile.png')});
  report.mobile=true;
  server=spawn(process.env.PYTHON_BIN||'python3',['app.py','--port','8767'],{cwd:root,stdio:['ignore','pipe','pipe']});
  await new Promise((resolve,reject)=>{
    server.stdout.once('data',resolve);server.once('error',reject);
    server.once('exit',code=>reject(new Error('Local server stopped: '+code)));
  });
  await page.goto('http://127.0.0.1:8767',{waitUntil:'load'});
  await page.locator('#liveN').fill('512');await page.locator('#liveSnr').fill('25');
  await page.locator('#liveGain').fill('0.8');await page.locator('#liveDc').fill('8');
  await page.locator('#liveClock').fill('1000');
  await page.locator('#simulate').click();
  await page.waitForFunction(()=>document.querySelector('#scenario').value==='custom');
  assert.equal(await page.locator('#liveResults tbody tr').count(),8);
  assert(await page.locator('#downloadLive').isEnabled());
  fs.writeFileSync(path.join(root,'results','new_browser_run.json'),await page.evaluate(()=>JSON.stringify(LIVE,null,2)));
  report.live=true;
  assert.deepEqual(report.errors,[]);
 }finally{
  if(server)server.kill();await browser.close();
  fs.writeFileSync(path.join(root,'results','browser_validation.json'),JSON.stringify(report,null,2));
 }
 console.log(JSON.stringify(report,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
