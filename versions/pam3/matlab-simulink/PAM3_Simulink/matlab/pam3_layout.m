function L = pam3_layout()
% Fixed-length per-channel state. Never grows with capture length.
L.tick = 1; L.length = 2; L.next = 3; L.previous = 4;
L.level = 5; L.initialized = 6; L.dc_filled = 7;
L.filter_initialized = 8; L.previous_filtered = 9;
L.edge_initialized = 10; L.direction = 11; L.last_edge = 12;
L.block_count = 13; L.ending = 14; L.flush_count = 15;
L.thresholds = 16:19; L.means = 20:22;
L.sums = 23:25; L.counts = 26:28;
L.dc = 29:155; L.raw = 156:160; L.raw_valid = 161:165;
L.level_ring = 166:197;
L.pending_keep = 198:201; L.pending_must = 202:205;
L.pending_mid = 206:209; L.anchors = 210:241;
L.candidates = 242:245; L.essential = 246:249;
L.size = 249;
end
