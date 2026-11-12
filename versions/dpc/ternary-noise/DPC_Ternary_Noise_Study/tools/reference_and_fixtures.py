"""Independent ABC/quadrature oracle. NOT an executed Simulink converter."""
from pathlib import Path
import re,zipfile,xml.etree.ElementTree as ET
import numpy as np
from numpy.polynomial.legendre import leggauss
from scipy.io import savemat

ROOT=Path(__file__).resolve().parents[1]
ABC=np.array([[1.,0.],[-.5,np.sqrt(3)/2],[-.5,-np.sqrt(3)/2]])
CLARKE=np.linalg.pinv(ABC)
GATES=np.array([[a,1-a,b,1-b,c,1-c] for a in [0,1] for b in [0,1] for c in [0,1]],float)
LEGS=GATES[:,[0,2,4]]
gx,gw=leggauss(16)

def read_source_table():
    with zipfile.ZipFile(ROOT/'source_model/DPC_POWER_RAHMAN_original.slx') as z:
        scripts=[]
        for name in z.namelist():
            if name.startswith('simulink/stateflow/') and name.endswith('.xml'):
                scripts += [p.text or '' for p in ET.fromstring(z.read(name)).iter('P') if p.get('Name')=='script']
    code=next(s for s in scripts if 'sw_array' in s)
    table=np.full((2,2,12,3),-1,int)
    for m in re.finditer(r'(?:if|elseif)\(\(sp==([01])\)&&\(sq==([01])\)\)(.*?)(?=elseif|\nend)',code,re.S):
        bp,bq=map(int,m.group(1,2))
        for row in re.finditer(r'sw_array\(:,(\d+)\)\s*=\s*\[([01]);([01]);([01])\]',m[3]):
            sector,a,b,c=map(int,row.group(1,2,3,4)); table[bp,bq,sector-1]=[a,b,c]
    assert np.all(table>=0)
    return table

SOURCE_TABLE=read_source_table()

def binary(previous,error):
    # Native R2024b observations: equality switches too. Keep the separately
    # defined ternary classifier's strict outer comparisons unchanged.
    return 1 if error>=1 else (0 if error<= -1 else previous)

def classify(previous,error,binary_value,enabled=True,ratio=.5):
    if not enabled:return 2*binary_value-1
    if error>1:return 1
    if error< -1:return -1
    if previous==1 and error>ratio:return 1
    if previous==-1 and error< -ratio:return -1
    return 0

def power_abc(v,i):
    return np.array([np.dot(v,i),np.dot([v[1]-v[2],v[2]-v[0],v[0]-v[1]],i)/np.sqrt(3)])

def predict(vabc,iabc,vdc,ts,resistance=.2,inductance=.015):
    # Independent quadrature of each physical phase and direct ABC power.
    e=CLARKE@vabc; i=CLARKE@iabc;omega=2*np.pi*50
    tau=(gx+1)*ts/2
    source=np.array([np.cos(omega*tau)*e[0]-np.sin(omega*tau)*e[1],
                     np.sin(omega*tau)*e[0]+np.cos(omega*tau)*e[1]])
    integrated=source@(gw*np.exp(-resistance*(ts-tau)/inductance))*ts/(2*inductance)
    decay=np.exp(-resistance*ts/inductance)
    hold=ts/inductance if resistance==0 else -np.expm1(-resistance*ts/inductance)/resistance
    source_next=ABC@np.array([[np.cos(omega*ts),-np.sin(omega*ts)],
                             [np.sin(omega*ts),np.cos(omega*ts)]])@e
    pred=[]
    for legs in LEGS:
        bridge=np.maximum(vdc,0)*(legs-np.mean(legs))
        next_i=ABC@(decay*i+integrated)-hold*bridge
        pred.append(power_abc(source_next,next_i))
    return np.array(pred).T,power_abc(vabc,iabc)

def select(sp,sq,sector,vabc,iabc,vdc,pref,qref,bp,bq,previous,ts,resistance=.2,guard=True):
    powers,now=predict(vabc,iabc,vdc,ts,resistance)
    ref=np.array([pref,qref]);baselegs=SOURCE_TABLE[bp,bq,sector-1]
    baseid=int(baselegs@np.array([4,2,1])); track=np.sum((powers-ref[:,None])**2,axis=0)
    result=[];guards=[]
    for p in [-1,0,1]:
        for q in [-1,0,1]:
            guarded=0
            if p and q:
                vector=int(SOURCE_TABLE[(p+1)//2,(q+1)//2,sector-1]@np.array([4,2,1]))
            else:
                target=now+np.array([p,q])*np.maximum(np.abs(ref-now),1.)
                costs=np.array([sum((powers[:,j]-target)**2) for j in range(8)])
                best=min(costs);options=np.flatnonzero(costs<=best+1e-12*max(1,abs(best)))
                vector=min(options,key=lambda j:(sum(LEGS[j]!=previous),j))
                if guard and track[vector]>track[baseid]+1e-12*max(1,track[baseid]):
                    vector=baseid;guarded=1
            result.append(vector);guards.append(guarded)
    row=3*(sp+1)+(sq+1);vector=result[row]
    audit=np.r_[sp,sq,sector,row+1,vector,now,powers[:,vector]-now,track[vector],track[baseid],guards[row],result]
    return GATES[vector],audit,np.array(result),powers

def operating_point(sector,p=400.,q=0.,vdc=150.,offset=0.):
    theta=np.deg2rad(15+30*(sector-1)+offset)
    e=50*np.sqrt(2)*np.array([np.cos(theta),np.sin(theta)])
    i=np.linalg.solve(1.5*np.array([[e[0],e[1]],[e[1],-e[0]]]),[p,q])
    return ABC@e,ABC@i,vdc

def main():
    rng=np.random.default_rng(20261015)
    inputs=[];expected_g=[];expected_a=[];expected_p=[]
    for fs in [20000.,200000.]:
        for sector in range(1,13):
            for p0,q0 in [(400.,0.),(150.,80.),(-50.,-50.)]:
                for sp in [-1,0,1]:
                    for sq in [-1,0,1]:
                        v,i,dc=operating_point(sector,p0,q0)
                        pref=p0+sp*20; qref=q0+sq*20
                        bp=1 if sp>0 else 0;bq=1 if sq>0 else 0
                        previous=rng.integers(0,2,3)
                        g,a,_,powers=select(sp,sq,sector,v,i,dc,pref,qref,bp,bq,previous,1/fs)
                        inputs.append(np.r_[sp,sq,sector,v,i,dc,pref,qref,bp,bq,previous,1/fs,.2])
                        expected_g.append(g);expected_a.append(a);expected_p.append(powers.reshape(-1))
    for _ in range(48):
        sec=int(rng.integers(1,13));sp,sq=rng.integers(-1,2,2);fs=float(rng.choice([20000,200000]));
        v,i,dc=operating_point(sec,float(rng.uniform(50,700)),float(rng.uniform(-100,100)),float(rng.uniform(120,210)))
        now=power_abc(v,i);ref=now+np.array([sp,sq])*15
        bp,bq=map(int,rng.integers(0,2,2));previous=rng.integers(0,2,3)
        g,a,_,powers=select(sp,sq,sec,v,i,dc,*ref,bp,bq,previous,1/fs,resistance=0)
        inputs.append(np.r_[sp,sq,sec,v,i,dc,*ref,bp,bq,previous,1/fs,0])
        expected_g.append(g);expected_a.append(a);expected_p.append(powers.reshape(-1))
    native=[]
    errors=np.array([(p*3,q*3) for p in [-1,0,1] for q in [-1,0,1] for _ in range(4)],float)
    bounds=np.array([-3,-1,-.5,0,.5,1,3,1,.50000001,.5,0,-3,-1,-.5])
    errors=np.vstack(([3,-3],errors,np.c_[bounds,bounds[::-1]],rng.normal(0,2,(180,2)),
                      np.repeat(rng.choice([-3.,0.,3.],size=(40,2)),5,axis=0)))
    for fs in [20000.,200000.]:
        matrix=[]
        for k,(ep,eq) in enumerate(errors):
            sec=1+k%12;v,i,dc=operating_point(sec,p=400+30*np.sin(k*.1),q=15*np.cos(k*.07))
            p,q=power_abc(v,i);matrix.append(np.r_[ep,eq,sec,v,i,dc,p+ep,q+eq])
        matrix=np.array(matrix);bp=bq=0;sp=sq=0;previous=np.zeros(3)
        bits=[];states=[];gates=[];original=[];audits=[]
        for x in matrix:
            bp=binary(bp,x[0]);bq=binary(bq,x[1]);sp=classify(sp,x[0],bp);sq=classify(sq,x[1],bq)
            base=SOURCE_TABLE[bp,bq,int(x[2])-1];original.append(GATES[int(base@[4,2,1])]);bits.append([bp,bq]);states.append([sp,sq])
            g,a,_,_=select(sp,sq,int(x[2]),x[3:6],x[6:9],x[9],x[10],x[11],bp,bq,previous,1/fs)
            previous=g[[0,2,4]];gates.append(g);audits.append(a)
        native.append(dict(fs=fs,input=matrix,binary=np.array(bits),states=np.array(states),
                           original_gates=np.array(original),proposed_gates=np.array(gates),audit=np.array(audits)))
    savemat(ROOT/'data/dpc3_golden.mat',dict(table_inputs=np.array(inputs),gates=np.array(expected_g),
        audit=np.array(expected_a),predictions=np.array(expected_p),native=np.array(native,dtype=object)[None,:],
        source_table=SOURCE_TABLE),do_compression=True)
    print(f'Independent fixtures: {len(inputs)} full table contexts; {len(native)} native cases x {len(errors)} samples; ABC/quadrature oracle.')

if __name__=='__main__':main()
