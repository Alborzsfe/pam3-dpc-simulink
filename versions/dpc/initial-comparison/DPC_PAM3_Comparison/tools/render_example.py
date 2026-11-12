"""Verify and render the ACTUAL Octave educational result. No fake screenshots."""
from pathlib import Path
import json, sys
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from generate_fixtures import expected

FOLDER = ROOT/'results/synthetic_educational'
result = loadmat(FOLDER/'comparison_result.mat', simplify_cells=True)['result']
t = result['capture']['time']*1000
assert result['kind'] == 'synthetic_educational'
assert not result['simulink_replay_executed']
checked = 0
for channel in [0,1]:
    c=result['channels'][channel]
    reference=expected(c['error'],mode=0)
    for field in ['binary','ternary','adc','raw']:
        np.testing.assert_array_equal(c[field],reference[field])
    for field in ['levels','points','symbols','thresholds']:
        np.testing.assert_array_equal(c['patent'][field],reference[field])
    np.testing.assert_allclose(c['symbol_latency_s'],20*5e-6,atol=1e-14,rtol=0)
    checked += len(c['error'])
(ROOT/'validation/example_reference_check.json').write_text(json.dumps(dict(
    passed=True,error_samples_checked=checked,reference='Independent Python offline oracles',
    numerical_execution='GNU Octave 8.4.0',plot_renderer='Python matplotlib',
    simulink_executed=False,converter_executed=False),indent=2)+'\n')

plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.spines.top':False,
                    'axes.spines.right':False,'axes.titleweight':'semibold',
                    'axes.labelcolor':'#26374b','text.color':'#26374b',
                    'figure.facecolor':'#ffffff','axes.grid':True,
                    'grid.alpha':.18,'savefig.facecolor':'#ffffff'})
COLORS=['#b16630','#198371','#8d5ea9','#3273a5']

for channel,label in enumerate(['P','Q']):
    c=result['channels'][channel]
    fig,axes=plt.subplots(4,1,figsize=(13.5,9),sharex=True,
                          gridspec_kw={'height_ratios':[1.5,1,1,1.2]})
    fig.suptitle(f'Identical-input detector comparison  |  channel {label}',x=.085,ha='left',fontsize=18)
    fig.text(.085,.923,'Synthetic educational input  |  computed in GNU Octave 8.4  |  Ts = 5 us',fontsize=11,color='#667486')
    axes[0].plot(t,c['error'],color='#283f5c',linewidth=.75,label='Power-error test input')
    axes[0].axhline(1,color='#8595a5',ls='--',lw=.9,label='Original activation limits +/-1')
    axes[0].axhline(-1,color='#8595a5',ls='--',lw=.9)
    axes[0].set_ylabel(f'e{label} (model units)');axes[0].legend(loc='upper right',frameon=False,fontsize=9)
    axes[1].step(t,c['binary'],where='post',color=COLORS[0],lw=1.2)
    axes[1].set_ylabel('Binary relay');axes[1].set_yticks([0,1]);axes[1].set_ylim(-.25,1.25)
    axes[2].step(t,c['ternary'],where='post',color=COLORS[1],lw=1.2)
    axes[2].set_ylabel('Control ternary');axes[2].set_yticks([-1,0,1]);axes[2].set_ylim(-1.3,1.3)
    axes[3].step(t,c['raw'],where='post',color=COLORS[2],lw=.75,label='Mapped patent: raw')
    filtered=c['filtered_causal'].copy();filtered[~c['filtered_valid'].astype(bool)]=np.nan
    axes[3].step(t,filtered,where='post',color=COLORS[3],lw=.85,label='Mapped patent: causal filter')
    axes[3].set_ylabel('Patent levels');axes[3].set_yticks([-1,0,1]);axes[3].set_ylim(-1.3,1.3)
    axes[3].legend(loc='lower right',ncol=2,frameon=False,fontsize=9)
    axes[3].set_xlabel('Time (ms)');axes[3].set_xlim(t[0],t[-1])
    fig.subplots_adjust(left=.085,right=.98,bottom=.085,top=.89,hspace=.24)
    fig.savefig(FOLDER/f'01_same_input_{label}.png',dpi=150)
    plt.close(fig)

fig,axes=plt.subplots(2,2,figsize=(13.5,7.4))
fig.suptitle('What changed in this educational example?',x=.08,ha='left',fontsize=18)
fig.text(.08,.92,'Identical inputs  |  comparison window: 3,999 valid samples per channel  |  no converter execution',fontsize=11,color='#667486')
labels=['Binary','Control\nternary','Patent\nraw','Patent\nfilter']
for channel,label in enumerate(['P','Q']):
    rows=result['channels'][channel]['metrics']
    for row_index,key,mult,ylabel in [(0,'decision_changes',1,'Decision changes'),(1,'neutral_fraction',100,'Neutral samples (%)')]:
        values=[r[key]*mult for r in rows]
        ax=axes[row_index,channel]
        bars=ax.bar(np.arange(4),values,color=COLORS,width=.6)
        ax.set_xticks(np.arange(4),labels)
        ax.set_ylabel(ylabel)
        if row_index==0:ax.set_title(f'Channel {label}',loc='left')
        ax.grid(axis='x',visible=False)
        ax.set_ylim(0,max(values)*1.25 if row_index==0 else 100)
        for b,value in zip(bars,values):
            ax.text(b.get_x()+b.get_width()/2,b.get_height()+(.9 if row_index==1 else max(values)*.035),
                    f'{value:.1f}%' if row_index==1 else str(int(value)),ha='center',fontsize=10)
fig.text(.08,.02,'A neutral state adds transitions. These counts are detector decisions, not semiconductor switching events.',fontsize=10,color='#667486')
fig.subplots_adjust(left=.08,right=.98,bottom=.11,top=.86,hspace=.42,wspace=.26)
fig.savefig(FOLDER/'02_decision_metrics.png',dpi=150);plt.close(fig)

c=result['channels'][0]
fig,axes=plt.subplots(3,1,figsize=(13.5,8.4),sharex=True)
fig.suptitle('Short impulses and patent output timing  |  channel P',x=.085,ha='left',fontsize=18)
fig.text(.085,.916,'Synthetic educational input  |  filter latency: 2 Ts = 10 us  |  symbol latency: 20 Ts = 100 us',fontsize=11,color='#667486')
axes[0].plot(t,c['error'],color='#283f5c',lw=.85);axes[0].set_ylabel('Same error input')
axes[0].axhline(1,color='#8c9aaa',ls='--',lw=.7);axes[0].axhline(-1,color='#8c9aaa',ls='--',lw=.7)
for tick,width,amplitude in [(2510,1,2.2),(2600,2,-2.2),(2720,3,2.2),(2850,8,-2.2)]:
    axes[0].annotate(f'{width} sample'+('s' if width>1 else ''),xy=(tick*.005,amplitude),
                     xytext=(tick*.005-.09,amplitude+(0.62 if amplitude>0 else -.58)),
                     fontsize=9,arrowprops={'arrowstyle':'-','color':'#657588'})
axes[0].set_ylim(-3.5,3.5)
axes[1].step(t,c['raw'],where='post',color=COLORS[2],lw=1,label='Raw direction-based level')
f=c['filtered_causal'].copy();f[~c['filtered_valid'].astype(bool)]=np.nan
axes[1].step(t,f,where='post',color=COLORS[3],lw=1.2,label='Causal spike-filter output')
axes[1].set_ylabel('Patent levels');axes[1].set_yticks([-1,0,1]);axes[1].set_ylim(-1.4,1.4)
axes[1].legend(loc='upper left',ncol=2,fontsize=9,frameon=False)
axes[2].step(t,c['ternary'],where='post',color=COLORS[1],lw=1,label='Control-oriented ternary')
stems=axes[2].stem(c['symbol_emission_time']*1000,c['patent']['symbols'],basefmt=' ',label='Patent symbol at EMISSION time')
plt.setp(stems.markerline,color=COLORS[3],markersize=4);plt.setp(stems.stemlines,color=COLORS[3],linewidth=.9)
axes[2].set_ylabel('Control / symbols');axes[2].set_yticks([-1,0,1]);axes[2].set_ylim(-1.4,1.4)
axes[2].legend(loc='upper left',ncol=2,fontsize=9,frameon=False)
axes[2].set_xlabel('Time (ms)');axes[2].set_xlim(12.3,14.7)
fig.subplots_adjust(left=.085,right=.98,bottom=.085,top=.875,hspace=.28)
fig.savefig(FOLDER/'03_patent_timing.png',dpi=150);plt.close(fig)
print(json.dumps({'independent_demo_samples_checked':checked,'figures_rendered':4,
                  'source':'Actual Octave numerical output; synthetic input'},indent=2))
