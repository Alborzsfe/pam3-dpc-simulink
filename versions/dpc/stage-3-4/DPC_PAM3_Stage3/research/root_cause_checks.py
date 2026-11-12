from pathlib import Path
import importlib.util,sys,json,numpy as np
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('original_patent',root/'original_receiver/python_reference/model.py')
m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
def reference(x):
 old=0;out=[]
 for e in x:
  if old==0:old=1 if e>=.01 else -1 if e<=-.01 else 0
  elif old==1:old=-1 if e<=-.01 else 0 if e<=.005 else 1
  else:old=1 if e>=.01 else 0 if e>=-.005 else -1
  out.append(old)
 return np.asarray(out)
r={}
for name,e in {'constant_positive_start':np.full(100,.02),
 'constant_negative_start':np.full(100,-.02),
 'positive_small_ripple':np.r_[np.zeros(10),np.tile([.015,.0154],50)],
 'falling_still_positive':np.r_[np.zeros(10),.02,np.full(50,.015)]}.items():
 adc=np.clip(np.floor(117.5+2250*e+.5),0,255).astype(int)
 raw=m.slope_decode(adc,m.DecoderConfig())[0];ref=reference(e)
 r[name]={'samples':len(e),'raw_mismatch_ticks':int(np.sum(raw!=ref)),
 'last_raw':int(raw[-1]),'last_reference':int(ref[-1])}
assert r['constant_positive_start']['raw_mismatch_ticks']==100
assert r['constant_negative_start']['raw_mismatch_ticks']==100
assert r['falling_still_positive']['raw_mismatch_ticks']==50
(root/'research/reproduced_logic_failures.json').write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))
