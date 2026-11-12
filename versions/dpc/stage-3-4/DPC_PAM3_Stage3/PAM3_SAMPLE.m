function x=PAM3_SAMPLE(s,t,label)
% Causal zero-order sampling. Unverified logs keep strict endpoint checks.
if nargin<3,label='unnamed signal';end
if isstruct(s) && isfield(s,'blockName'),label=char(s.blockName);end
assert(isstruct(s) && isfield(s,'time') && isfield(s,'signals') && ...
    isfield(s.signals,'values'),'PAM3Study:LogFormat','Invalid log for %s.',label);
time=double(s.time(:));query=double(t(:));
assert(~isempty(time) && ~isempty(query) && all(isfinite(time)) && ...
    all(isfinite(query)) && all(diff(time)>=0), ...
    'PAM3Study:LogTime','Empty, nonfinite or decreasing time in %s.',label);
assert(~isempty(s.signals.values) && mod(numel(s.signals.values),numel(time))==0, ...
    'PAM3Study:LogShape','Time/value sizes do not match in %s.',label);
x=reshape(double(s.signals.values),numel(time),[]);
[time,keep]=unique(time,'last');x=x(keep,:);
tol=64*eps(max([1;abs(time);abs(query)]));
first=min(query);last=max(query);
rightOK=last<=time(end)+tol;
if ~rightOK && isfield(s,'pam3Logging')
    a=s.pam3Logging;
    % Coverage was checked AFTER a completed simulation. A periodic sample
    % remains valid until its next hit, but never invent that next sample.
    rightOK=a.Verified && last<=a.StopTime+tol && ...
        last<time(end)+a.SampleTime-tol;
end
assert(first>=time(1)-tol && rightOK,'PAM3Study:Window', ...
    ['Missing analysis window for %s: requested [%.17g, %.17g] s; ' ...
     'recorded [%.17g, %.17g] s (%d unique samples).'], ...
    label,first,last,time(1),time(end),numel(time));
% Clamp only roundoff and the verified final held interval. The tolerance
% also resolves equivalent floating-point representations of a sample hit.
query=min(max(query+tol,time(1)),time(end));
if numel(time)==1
    x=repmat(x,numel(query),1);
else
    x=interp1(time,x,query,'previous');
end
end
