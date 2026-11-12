"""Algorithm/property checks + approximate alpha-beta plant, NOT Simulink.
No numbers in this file are presented as the user's converter results.
"""
from pathlib import Path
import json, math, sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]

def baseline_step(old,e,hi=.01,lo=.005):
    if old==0:return 1 if e>=hi else -1 if e<=-hi else 0
    if old==1:return -1 if e<=-hi else 0 if e<=lo else 1
    return 1 if e>=hi else 0 if e>=-lo else -1

def fast_step(s,e,gain=.5,floor=.015):
    hi=.01;lo=.005
    if not s[6]:s[1]=e;s[2]=e;s[6]=1
    d2=np.clip(e-2*s[1]+s[2],-.06,.06)
    s[3]+=d2*d2/6;s[4]+=1
    if s[4]==12:s[5]+=(s[3]/12-s[5])/8;s[3]=s[4]=0
    s[7]=min(2000,s[7]+1)
    s[2]=s[1];s[1]=e
    if gain>0 and abs(e)<.025 and s[7]>=2000:
        extra=min(.005,max(0,gain*(math.sqrt(max(0,s[5]))-floor)))
        hi+=extra;lo+=.5*extra
    y=baseline_step(s[0],e,hi,lo);s[0]=y
    return y,hi,lo

def properties():
    rng=np.random.default_rng(321)
    x=np.r_[0,.01,-.01,.005,-.005,np.nextafter(.01,0),
            np.nextafter(-.01,0),rng.normal(0,.02,100000),1,-1]
    s=np.zeros(8);old=0
    for e in x:
        y,hi,lo=fast_step(s,e,0);old=baseline_step(old,e)
        assert y==old and hi==.01 and lo==.005
    constant=[]
    for e in [.02,-.02,1,-1]:
        s=np.zeros(8)
        y,_,_=fast_step(s,e)
        assert y==np.sign(e)
        constant.append({'e':e,'first_sample_decision':y})
    s=np.zeros(8)
    for e in rng.normal(0,.03,50000):
        y,hi,lo=fast_step(s,e)
        assert y in [-1,0,1] and .01<=hi<=.015 and .005<=lo<=.0075
        if abs(e)>=.025:assert y==np.sign(e)
    return {'compatibility_samples':len(x),'compatibility_decision_mismatches':0,
            'bounded_band_and_emergency_samples':50000,'constant_start_tests':constant,
            'scope':'Python translation; native MATLAB tests also supplied'}

def simulate(gain=0,noise=0,seed=321):
    # Ideal voltage-source switching bridge, RL input, DC capacitor + R load.
    # Continuous PI discretized by Euler. Diodes, exact powergui algorithm,
    # Simulink event ordering, and parasitics are NOT reproduced.
    dt=1/40000;n=20000;ia=ib=0.;vdc=150.;integral=0.;lastP=lastQ=-1
    vector=np.zeros(3);valid=False;sP=np.zeros(8);sQ=np.zeros(8)
    rng=np.random.default_rng(seed)
    table=np.array([[4,4,5,5,6,6,1,1,2,2,3,3],
       [6,6,1,1,2,2,3,3,4,4,5,5],
       [2,2,3,3,4,4,5,5,6,6,1,1],
       [1,1,2,2,3,3,4,4,5,5,6,6]])
    vectors=np.array([[1,0,0],[1,1,0],[0,1,0],[0,1,1],[0,0,1],[1,0,1]])
    result=np.empty((n,4))
    for k in range(n):
        angle=2*math.pi*50*k*dt
        va=50*math.sqrt(2)*math.cos(angle);vb=50*math.sqrt(2)*math.sin(angle)
        p=1.5*(va*ia+vb*ib);q=1.5*(vb*ia-va*ib)
        pref=(.5*(150-vdc)+integral)*vdc;base=max(1,abs(pref))
        np_,nq=rng.normal(0,noise,2)
        ep=(pref-p-np_)/base;eq=(-q-nq)/base
        sp,_,_=fast_step(sP,ep,gain);sq,_,_=fast_step(sQ,eq,gain)
        theta=math.atan2(vb,va)
        if theta>0:sec=int(math.ceil(theta/(math.pi/6)))
        elif theta<=-5*math.pi/6:sec=7
        elif theta<=-2*math.pi/3:sec=8
        elif theta<=-math.pi/2:sec=9
        elif theta<=-math.pi/3:sec=10
        elif theta<=-math.pi/6:sec=11
        else:sec=12
        if not(sp==0 and sq==0 and valid):
            if sp:lastP=sp
            if sq:lastQ=sq
            row=(0 if lastP==1 else 2)+(0 if lastQ==1 else 1)
            vector=vectors[table[row,sec-1]-1];valid=True
        ualpha=2/3*vdc*(vector[0]-.5*vector[1]-.5*vector[2])
        ubeta=math.sqrt(3)/3*vdc*(vector[1]-vector[2])
        result[k]=p,q,ia,vdc
        # One Euler step is deliberately documented as an approximation.
        dc_i=1.5*(ualpha*ia+ubeta*ib)/max(1,vdc)
        ia+=dt*(va-ualpha-.2*ia)/.015
        ib+=dt*(vb-ubeta-.2*ib)/.015
        vdc+=dt*(dc_i-vdc/57)/.0108
        integral+=dt*(150-vdc)
    use=result[12000:16000]
    a=2*np.abs(np.fft.rfft(use[:,2]-use[:,2].mean()))/len(use)
    return {'P_mean_W':float(use[:,0].mean()),'P_ripple_RMS_W':float(use[:,0].std()),
      'Q_mean_var':float(use[:,1].mean()),'Q_ripple_RMS_var':float(use[:,1].std()),
      'Ia_THD_2kHz_pct':float(100*np.sqrt(np.sum(a[np.arange(2,41)*5]**2))/a[5]),
      'Vdc_mean_V':float(use[:,3].mean()),'Vdc_ripple_pp_V':float(np.ptp(use[:,3]))}

if __name__=='__main__':
    r={'property_tests':properties(),'approximate_plant_runs':[]}
    for noise in [0,8]:
        for gain in [0,.5]:
            for seed in ([321] if noise==0 else [321,654,987]):
                metrics=simulate(gain,noise,seed)
                r['approximate_plant_runs'].append({'gain':gain,'noise_std_W_var':noise,'seed':seed,**metrics})
                print(noise,gain,seed,metrics,flush=True)
    r['limitation']='Approximate exploratory plant only; these are NOT MATLAB/Simulink results or proof of improvement.'
    (ROOT/'research/offline_validation.json').write_text(json.dumps(r,indent=2))
