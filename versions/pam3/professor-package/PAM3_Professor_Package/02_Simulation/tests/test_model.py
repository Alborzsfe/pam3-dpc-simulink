import unittest
from dataclasses import replace
import numpy as np
from pam3.model import *
from pam3.channel import *

class ModelTests(unittest.TestCase):
    def test_rolling_window_against_direct_extrema(self):
        x=np.random.default_rng(19).integers(0,256,400)
        for w in [1,12,128]:
            mn,mx=rolling_extrema(x,w)
            np.testing.assert_array_equal(mn,[min(x[max(0,i-w+1):i+1]) for i in range(len(x))])
            np.testing.assert_array_equal(mx,[max(x[max(0,i-w+1):i+1]) for i in range(len(x))])

    def test_dc_literal_equation_widened_and_strict_overflow(self):
        x=np.array([60,194,255,0,200])
        y,active=dc_correct(x,DecoderConfig(dc_enabled=True))
        for i in range(len(x)):
            mn=min(x[:i+1]);mx=max(x[:i+1]);v=int(x[i]-mn+95)
            expected=v if mx>140 and mn<80 and v<255 else x[i]
            self.assertEqual(y[i],expected)

    def test_dc_bypasses_two_level_without_positive(self):
        x=np.resize([60,127],1024)
        y,active=dc_correct(x,DecoderConfig(dc_enabled=True))
        np.testing.assert_array_equal(x,y);self.assertFalse(active.any())

    def test_dc_bypasses_two_level_without_negative(self):
        x=np.resize([127,194],1024)
        y,active=dc_correct(x,DecoderConfig(dc_enabled=True))
        np.testing.assert_array_equal(x,y);self.assertFalse(active.any())

    def test_slopes_hold_on_equal_samples(self):
        levels,_=slope_decode([127,194,194,150,60,60,100,127],DecoderConfig())
        np.testing.assert_array_equal(levels,[0,1,1,0,-1,-1,0,0])

    def test_spike_two_samples_removed_three_retained(self):
        x=np.r_[np.ones(10),np.zeros(2),np.ones(10)].astype(np.int8)
        np.testing.assert_array_equal(spike_filter(x),np.ones(22))
        x=np.r_[np.ones(10),np.zeros(3),np.ones(10)].astype(np.int8)
        np.testing.assert_array_equal(spike_filter(x),x)

    def test_figure4g_zero_valley_midpoint(self):
        x=np.r_[np.ones(10),np.zeros(3),np.ones(15)].astype(np.int8)
        info=edge_analysis(x,DecoderConfig())
        np.testing.assert_array_equal(info["anchors"],[11])
        self.assertIn(13,info["must_edges"])

    def test_sampling_filter_keeps_must_and_removes_forecast(self):
        p,m,c=sampling_points(40,np.array([9,21]),DecoderConfig())
        np.testing.assert_array_equal(p,[9,21,33])
        np.testing.assert_array_equal(m,[True,True,False])

    def test_high_snr_reconstruction_and_two_channel_phases(self):
        for phase in [0,1.7,9.0]:
            s=generate_channel(ChannelConfig(n_symbols=1024,snr_db=50,phase_samples=phase))
            self.assertEqual(evaluate(s,decode(s["adc"]))["errors"],0)

    def test_missing_and_extra_are_errors_not_dropped(self):
        s=generate_channel(ChannelConfig(n_symbols=256,snr_db=50))
        points=s["centers"].astype(int)
        values=s["tx"].copy()
        result=evaluate(s,dict(points=points,symbols=values))
        self.assertEqual(result["errors"],0)
        idx=70
        p=np.delete(points,idx);v=np.delete(values,idx)
        r=evaluate(s,dict(points=p,symbols=v));self.assertEqual(r["missing"],1);self.assertEqual(r["errors"],1)
        p=np.insert(points,idx,points[idx]);v=np.insert(values,idx,values[idx])
        r=evaluate(s,dict(points=p,symbols=v));self.assertEqual(r["extra_outputs"],1);self.assertEqual(r["errors"],1)

    def test_decoder_does_not_receive_truth_or_channel_parameters(self):
        s=generate_channel(ChannelConfig(n_symbols=512))
        a=decode(s["adc"],DecoderConfig(adaptive=True))
        s["tx"]=-s["tx"];s["centers"]+=4
        b=decode(s["adc"],DecoderConfig(adaptive=True))
        np.testing.assert_array_equal(a["points"],b["points"])
        np.testing.assert_array_equal(a["symbols"],b["symbols"])

    def test_reproducible_jitter_noise_and_no_negative_duration(self):
        cfg=ChannelConfig(n_symbols=512,jitter_rms_samples=1.2,seed=923)
        a,b=generate_channel(cfg),generate_channel(cfg)
        np.testing.assert_array_equal(a["adc"],b["adc"])
        self.assertTrue(np.all(np.diff(a["boundaries"])>0))

    def test_literal_dc_conflict_is_observable(self):
        s=generate_channel(ChannelConfig(n_symbols=512,snr_db=50))
        off=evaluate(s,decode(s["adc"]))
        on=evaluate(s,decode(s["adc"],DecoderConfig(dc_enabled=True)))
        self.assertEqual(off["errors"],0);self.assertGreater(on["ser_total"],0.1)

if __name__=="__main__": unittest.main()
