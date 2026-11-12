function d = pam3_trace_decode(trace)
% Convert the 18-column sample-rate debug interface into chronological arrays.
real_rows = trace(:, 6) ~= 0;
filter_rows = trace(:, 8) ~= 0;
output_rows = trace(:, 1) ~= 0;
d.corrected = trace(real_rows, 4);
d.raw_levels = trace(real_rows, 5);
d.thresholds = trace(real_rows, 10:13);
d.levels = trace(filter_rows, 7);
d.filtered_indices = trace(filter_rows, 9);
d.points = trace(output_rows, 3);
d.symbols = trace(output_rows, 2);
d.trace = trace;
assert(isequal(d.filtered_indices, (0:numel(d.levels)-1)'), ...
    'PAM3:FilterOrder', 'Filtered indices must be contiguous.');
end
