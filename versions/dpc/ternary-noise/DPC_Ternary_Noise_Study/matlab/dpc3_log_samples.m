function values = dpc3_log_samples(log,ts,count,width,name)
time = double(log.time(:));
assert(numel(time) == count,'DPC3:Count','%s expected %d samples, got %d.',name,count,numel(time));
expected = (0:count-1)'*ts;
tolerance = min(ts/1000,128*eps(max(1,max(abs(expected)))));
assert(all(isfinite(time)) && all(abs(time-expected) <= tolerance),'DPC3:Clock','%s clock mismatch.',name);
data = double(log.signals.values);
if size(data,1) ~= count && size(data,ndims(data)) == count
    data = permute(data,[ndims(data),1:ndims(data)-1]);
end
assert(numel(data) == count*width && all(isfinite(data(:))),'DPC3:LogWidth','%s width or values invalid.',name);
values = reshape(data,count,width);
end
