function x=PAM3_SAMPLE(s,t)
x=reshape(double(s.signals.values),numel(s.time),[]);
[time,keep]=unique(double(s.time(:)),'last');x=x(keep,:);
assert(time(1)<=t(1) && time(end)>=t(end),'PAM3Study:Window','Missing analysis window.');
x=interp1(time,x,t,'previous');
end
