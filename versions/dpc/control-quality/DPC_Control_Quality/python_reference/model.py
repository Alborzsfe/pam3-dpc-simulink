from dataclasses import dataclass, asdict
import numpy as np
from scipy.ndimage import minimum_filter1d, maximum_filter1d


@dataclass(frozen=True)
class DecoderConfig:
    plus: int = 140
    minus: int = 95
    zero_plus: int = 160
    zero_minus: int = 80
    samples_per_symbol: int = 12
    dc_window: int = 128
    dc_enabled: bool = False  # Explicitly permitted bypass in patent, col. 6.
    dc_min_gate: int = 80     # Minus_Maximum_Threshold not numerically disclosed.
    dc_anchor: int = 95       # Literal printed Minus_Threshold.
    adaptive: bool = False   # Update law is an engineering assumption.
    spike_max_width: int = 2 # Preserve Figure 4G's three-sample genuine pulse.
    minimum_edge_distance: int = 9
    lookahead: int = 4
    initial_phase: int = 6   # Fixed receiver initialization, independent of TX.


def rolling_extrema(data, window=128):
    """Current sample plus previous window-1; absent history repeats first sample."""
    x = np.asarray(data, dtype=np.int32)
    pad = np.pad(x, (window - 1, 0), mode="edge")
    # SciPy centered filters shifted so the window ends at each current sample.
    mn = minimum_filter1d(pad, size=window, origin=(window - 1)//2, mode="nearest")
    mx = maximum_filter1d(pad, size=window, origin=(window - 1)//2, mode="nearest")
    return mn[window-1:], mx[window-1:]


def dc_correct(data, cfg):
    x = np.asarray(data, dtype=np.int32)
    if not cfg.dc_enabled:
        return x.copy(), np.zeros(len(x), dtype=bool)
    mn, mx = rolling_extrema(x, cfg.dc_window)
    candidate = x - mn + cfg.dc_anchor
    enabled = (mx > cfg.plus) & (mn < cfg.dc_min_gate) & (candidate < 255)
    # The patent uses <255, not <=255. All arithmetic is widened before comparison.
    return np.where(enabled, candidate, x), enabled


def slope_decode(data, cfg):
    """Four thresholds, strict printed rising comparisons; mirrored falling rule."""
    x = np.asarray(data, dtype=np.int32)
    out = np.zeros(len(x), dtype=np.int8)
    trace = np.empty((len(x), 4), dtype=np.int16)
    thresholds = [cfg.plus, cfg.minus, cfg.zero_plus, cfg.zero_minus]
    means = [60.0, 127.0, 194.0]
    sums, counts = [0, 0, 0], [0, 0, 0]
    level = 0
    previous = int(x[0])
    for i, value in enumerate(x):
        value = int(value)
        plus, minus, zp, zm = thresholds
        if value > previous:
            if value > plus:
                level = 1
            elif value < plus and value > zm:
                level = 0
        elif value < previous:
            if value < minus:
                level = -1
            elif value > minus and value < zp:
                level = 0
        out[i] = level
        trace[i] = thresholds
        if cfg.adaptive:
            j = level + 1
            sums[j] += value
            counts[j] += 1
            if (i + 1) % cfg.samples_per_symbol == 0:
                # Causal decision-directed EWMA: update only after finishing block.
                # No transmitted labels, SNR, gain, or offset are supplied here.
                for k in range(3):
                    if counts[k] >= 3:
                        means[k] += (sums[k]/counts[k] - means[k]) / 8.0
                if means[1]-means[0] >= 12 and means[2]-means[1] >= 12:
                    low, mid, high = means
                    thresholds = [
                        int(np.clip(np.rint(mid + (high-mid)*13/67), 1, 254)),
                        int(np.clip(np.rint(mid - (mid-low)*32/67), 1, 254)),
                        int(np.clip(np.rint(mid + (high-mid)*33/67), 1, 254)),
                        int(np.clip(np.rint(mid - (mid-low)*47/67), 1, 254)),
                    ]
                sums, counts = [0, 0, 0], [0, 0, 0]
        previous = value
    return out, trace


def spike_filter(levels, max_width=2):
    """Fill isolated runs <=max_width only when both original neighbours agree."""
    x = np.asarray(levels, dtype=np.int8)
    result = x.copy()
    edges = np.r_[0, np.flatnonzero(np.diff(x)) + 1, len(x)]
    for j in range(1, len(edges)-2):
        start, stop = int(edges[j]), int(edges[j+1])
        if stop-start <= max_width and x[start-1] == x[stop]:
            result[start:stop] = x[start-1]
    return result


def edge_analysis(levels, cfg):
    """Opposite edge slopes bounding a pulse: Figure 2 and Figure 4G interpretation."""
    x = np.asarray(levels, dtype=np.int8)
    edges = np.flatnonzero(np.diff(x)) + 1
    directions = np.sign(x[edges].astype(int)-x[edges-1].astype(int))
    must = np.zeros(len(edges), dtype=bool)
    midpoints = np.full(len(edges), -1, dtype=np.int64)
    for j in range(1, len(edges)):
        distance = int(edges[j]-edges[j-1])
        if directions[j] != directions[j-1] and distance <= cfg.samples_per_symbol:
            must[j] = True
            # floor midpoint of plateau [first edge, second edge), not a boundary.
            midpoints[j] = (int(edges[j-1])+int(edges[j])-1)//2
    previous_raw = np.r_[-cfg.minimum_edge_distance, edges[:-1]]
    keep1 = must | (edges-previous_raw >= cfg.minimum_edge_distance)
    e1, m1, p1 = edges[keep1], must[keep1], midpoints[keep1]
    keep2 = np.ones(len(e1), dtype=bool)
    for j in range(len(e1)):
        k = j+1
        while k < len(e1) and e1[k]-e1[j] <= cfg.lookahead:
            if m1[k]:
                keep2[j] = False
                break
            k += 1
    return dict(edges=edges, must_edges=edges[must], first_edges=e1,
                second_edges=e1[keep2], anchors=p1[keep2 & m1])


def sampling_points(length, anchors, cfg):
    """Fixed 12-sample free-run, reset to each retained must midpoint, then filter."""
    candidates, essential = [], []
    next_point = cfg.initial_phase
    for anchor in np.unique(anchors):
        anchor = int(anchor)
        if anchor < 0 or anchor >= length:
            continue
        while next_point < anchor:
            candidates.append(next_point); essential.append(False)
            next_point += cfg.samples_per_symbol
        candidates.append(anchor); essential.append(True)
        next_point = anchor + cfg.samples_per_symbol
    while next_point < length:
        candidates.append(next_point); essential.append(False)
        next_point += cfg.samples_per_symbol
    c = np.asarray(candidates, dtype=np.int64)
    e = np.asarray(essential, dtype=bool)
    keep = np.ones(len(c), dtype=bool)
    # Every must candidate retained; discard a non-must candidate if another <=4 later.
    if len(c)>1:
        keep[:-1] = e[:-1] | (np.diff(c) > cfg.lookahead)
    return c[keep], e[keep], c


def decode(adc, cfg=DecoderConfig()):
    corrected, dc_active = dc_correct(adc, cfg)
    raw_levels, thresholds = slope_decode(corrected, cfg)
    levels = spike_filter(raw_levels, cfg.spike_max_width)
    edge = edge_analysis(levels, cfg)
    points, essential, candidates = sampling_points(len(levels), edge["anchors"], cfg)
    return dict(adc=np.asarray(adc), corrected=corrected, dc_active=dc_active,
                raw_levels=raw_levels, levels=levels, thresholds=thresholds,
                points=points, symbols=levels[points], essential=essential,
                candidates=candidates, **edge)


def naive_decode(adc, cfg=DecoderConfig()):
    """Two fixed amplitude thresholds plus uncorrected fixed receiver clock baseline."""
    x = np.asarray(adc)
    levels = np.where(x<cfg.minus, -1, np.where(x>cfg.zero_plus, 1, 0)).astype(np.int8)
    points = np.arange(cfg.initial_phase, len(x), cfg.samples_per_symbol)
    return dict(points=points, symbols=levels[points], levels=levels)


def config_dict(cfg):
    return asdict(cfg)
