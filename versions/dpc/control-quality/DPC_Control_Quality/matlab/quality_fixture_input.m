function input = quality_fixture_input(values, sample_time)
% Same [time,value] format as the PAM3 model previously run in R2024b.
values = double(values(:));
assert(~isempty(values) && all(isfinite(values)));
assert(isscalar(sample_time) && isfinite(sample_time) && sample_time > 0);
time = (0:numel(values)-1)'*sample_time;
input = [time,values];
end
