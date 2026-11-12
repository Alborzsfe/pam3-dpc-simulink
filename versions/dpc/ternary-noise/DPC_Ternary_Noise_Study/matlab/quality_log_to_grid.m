function values = quality_log_to_grid(log, query, name)
% Causal ZOH, duplicate timestamps keep last, singleton constants hold.
time = double(log.time(:)); assert(~isempty(time), 'QUALITY:EmptyLog', 'Empty %s log.', name);
data = double(log.signals.values);
if size(data, 1) ~= numel(time) && size(data, ndims(data)) == numel(time)
    order = [ndims(data), 1:ndims(data)-1]; data = permute(data, order);
end
data = reshape(data, numel(time), []);
assert(all(isfinite(time)) && all(isfinite(data(:))), 'QUALITY:Nonfinite', ...
    'Nonfinite data in %s. Simulation cannot be treated as a valid quality result.', name);
[time, indices] = unique(time, 'last'); data = data(indices, :);
assert(query(1) >= time(1)-1e-11, 'QUALITY:LogStart', 'Requested window starts before %s data.', name);
if numel(time) == 1
    values = repmat(data, numel(query), 1);
else
    assert(query(end) <= time(end)+1e-11, 'QUALITY:LogEnd', 'Requested window exceeds %s data.', name);
    bounded = min(time(end), max(time(1), query));
    values = interp1(time, data, bounded, 'previous');
    % Snap ONLY roundoff-equivalent clock representations to the logged sample.
    nearest = interp1(time,(1:numel(time))',bounded,'nearest');
    nearest = round(nearest);
    tolerance = 128*eps(max(1,max(abs(time))));
    same_clock = abs(time(nearest)-bounded) <= tolerance;
    values(same_clock,:) = data(nearest(same_clock),:);
end
end
