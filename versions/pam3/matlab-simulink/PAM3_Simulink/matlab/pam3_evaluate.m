function metrics = pam3_evaluate(tx, boundaries, decoded)
% TX truth is used here only. Exactly one correct output per interval is required.
tx = double(tx(:)); boundaries = double(boundaries(:));
points = double(decoded.points(:)); symbols = double(decoded.symbols(:));
[~, bins] = histc(points, boundaries); %#ok<HISTC>
first = 33; last = numel(tx)-8;
assert(last >= first, 'PAM3:Evaluation', 'Use at least 41 transmitted symbols.');
counts = zeros(numel(tx), 1); correct = false(numel(tx), 1);
for k = 1:numel(points)
    j = bins(k);
    if j >= first && j <= last
        counts(j) = counts(j) + 1;
        correct(j) = symbols(k) == tx(j);
    end
end
correct = correct & counts == 1;
indices = first:last; n = numel(indices);
errors = n - sum(correct(indices));
metrics = struct('evaluated', n, 'errors', errors, 'ser_total', errors/n, ...
    'missing', sum(counts(indices) == 0), ...
    'duplicated_intervals', sum(counts(indices) > 1), ...
    'wrong_value_single', sum(counts(indices) == 1 & ~correct(indices)), ...
    'warmup_excluded', 32, 'tail_excluded', 8);
end
