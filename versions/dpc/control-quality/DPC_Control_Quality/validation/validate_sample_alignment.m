function report = validate_sample_alignment()
% Reproduce the false fixture-7 failure without claiming native Simulink.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'));
data = load(fullfile(root,'data','quality_fixtures.mat')); item = data.cases{7};
n = numel(item.errors); dt = 1/item.fs;
log.time = (0:n-1)'*dt; log.signals.values = double(item.expected(:));
old_query = (0:n-1)'/item.fs;
old_actual = quality_log_to_grid(log,old_query,'old comparison');
false_mismatches = sum(old_actual ~= item.expected(:));
assert(false_mismatches > 0, 'Expected reproduction of strict-ZOH clock boundary artifact.');
actual = quality_discrete_samples(log,dt,n,'aligned comparison');
assert(isequal(actual,double(item.expected(:))));
% Value mismatches must remain visible; no lag fitting or value tolerance.
changed = log; changed.signals.values(20) = 1-changed.signals.values(20);
actual = quality_discrete_samples(changed,dt,n,'changed sample');
assert(sum(actual ~= item.expected(:)) == 1);
% Missing samples and a real fractional-clock shift must both fail.
short = log; short.time = short.time(1:end-1); short.signals.values = short.signals.values(1:end-1);
rejected_count = false;
try, quality_discrete_samples(short,dt,n,'missing sample'); catch exception
    rejected_count = strcmp(exception.identifier,'QUALITY:SampleCount');
end
assert(rejected_count);
shifted = log; shifted.time = shifted.time+dt/4;
rejected_clock = false;
try, quality_discrete_samples(shifted,dt,n,'shifted clock'); catch exception
    rejected_clock = strcmp(exception.identifier,'QUALITY:SampleClock');
end
assert(rejected_clock);
report = struct('passed',true,'reproduced_false_mismatches',false_mismatches, ...
    'corrected_mismatches',0,'true_value_error_preserved',true, ...
    'missing_sample_rejected',true,'real_clock_shift_rejected',true, ...
    'simulink_executed',false,'runtime',version);
fprintf('PASS sample alignment: reproduced %d false mismatches; exact indexing gives 0; real errors still rejected.\n', ...
    false_mismatches);
end
