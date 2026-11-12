"""Sample-causal Q8 adaptive front end; offline independent edge/sampling oracle.

Fixed mode equals the previous functional model. The Q8 update law is an
engineering reconstruction, not an update law disclosed by the patent.
"""
import numpy as np
from .model import DecoderConfig, spike_filter, edge_analysis, sampling_points


def decode_integer(adc, cfg=DecoderConfig()):
    adc = np.asarray(adc, dtype=np.int32)
    corrected = np.zeros(len(adc), dtype=np.int32)
    raw = np.zeros(len(adc), dtype=np.int8)
    trace = np.empty((len(adc), 4), dtype=np.int16)
    thresholds = [cfg.plus, cfg.minus, cfg.zero_plus, cfg.zero_minus]
    means = [60*256, 127*256, 194*256]
    sums, counts = [0]*3, [0]*3
    previous, level = 0, 0
    for i, original in enumerate(adc):
        plus, minus, zp, zm = thresholds
        trace[i] = thresholds
        value = int(original)
        if cfg.dc_enabled:
            hist = adc[max(0, i-127):i+1]
            lo, hi = int(hist.min()), int(hist.max())
            cand = value-lo+cfg.dc_anchor
            if hi > plus and lo < cfg.dc_min_gate and cand < 255:
                value = cand
        corrected[i] = value
        if i:
            if value > previous:
                if value > plus: level = 1
                elif value < plus and value > zm: level = 0
            elif value < previous:
                if value < minus: level = -1
                elif value > minus and value < zp: level = 0
        previous = value
        raw[i] = level
        if cfg.adaptive:
            sums[level+1] += value
            counts[level+1] += 1
            if (i+1) % 12 == 0:
                for k in range(3):
                    if counts[k] >= 3:
                        avg = (sums[k]*256)//counts[k]
                        means[k] += (avg-means[k])//8
                gl, gh = means[1]-means[0], means[2]-means[1]
                if gl >= 12*256 and gh >= 12*256:
                    q8 = [means[1]+gh*13//67, means[1]-gl*32//67,
                          means[1]+gh*33//67, means[1]-gl*47//67]
                    thresholds = [max(1, min(254, (v+128)//256)) for v in q8]
                sums, counts = [0]*3, [0]*3
    levels = spike_filter(raw, cfg.spike_max_width)
    edges = edge_analysis(levels, cfg)
    points, essential, candidates = sampling_points(len(adc), edges['anchors'], cfg)
    return dict(adc=adc, corrected=corrected, raw_levels=raw, levels=levels,
                thresholds=trace, points=points, symbols=levels[points],
                essential=essential, candidates=candidates, **edges)
