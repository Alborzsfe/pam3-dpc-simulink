"""Review snapshot of the DYNAMIC table, not converter experiment output."""
from pathlib import Path
import csv
from reference_and_fixtures import operating_point,select
import numpy as np
root=Path(__file__).resolve().parents[1]
with (root/'docs/nominal_table_snapshot.csv').open('w',newline='') as f:
    writer=csv.writer(f);writer.writerow(['control_Fs_Hz','sector','sp','sq','binary_dp','binary_dq',
        'vector_id_4A_2B_C','upper_A','upper_B','upper_C','predicted_delta_P_W','predicted_delta_Q_var','guard_used'])
    for fs in [20000,200000]:
        for sector in range(1,13):
            for sp in [-1,0,1]:
                for sq in [-1,0,1]:
                    v,i,dc=operating_point(sector)
                    bp=int(sp>0);bq=int(sq>0)
                    g,a,_,_=select(sp,sq,sector,v,i,dc,400+sp*20,sq*20,bp,bq,np.zeros(3),1/fs)
                    writer.writerow([fs,sector,sp,sq,bp,bq,int(a[4]),*map(int,g[[0,2,4]]),a[7],a[8],int(a[11])])
print('Wrote 216-row NOMINAL dynamic-table review snapshot (not a simulation result).')
