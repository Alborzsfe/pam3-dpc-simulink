function VALIDATE_PAM3_LOGGING()
% MATLAB-only regression fixtures. Does not simulate the power converter.
VALIDATE_PAM3_COMPLETION();
[cfg,~]=research_stage3_config();cfg.sourcePhaseScale=[1 1 1];
n=round(cfg.stopTime/cfg.Ts);t=(0:n-1)'*cfg.Ts;
ta=t+.5*cfg.Ts;
v=zeros(numel(t),3);
for k=1:numel(t),v(k,:)=pam3_grid_wave(t(k),50,50,0)';end
raw=struct('V',signal(t,v),'Pref',signal(t,400*ones(size(t))), ...
    'Qref',signal(t,zeros(size(t))));
[verified,coverage]=PAM3_LOG_COVERAGE(raw,cfg,cfg.stopTime);
assert(all(coverage.FinalIntervalHeld));
assert(isequal(PAM3_SAMPLE(verified.Pref,ta),400*ones(size(ta))));
o=PAM3_STAGE3_OBSERVATIONS(verified,cfg);
assert(o.VoltageVerified && o.ReferencesVerified);
expect_error(@()PAM3_SAMPLE(raw.Pref,ta),'PAM3Study:Window');
% A held interval is valid strictly before the next hit, never beyond it.
expect_error(@()PAM3_SAMPLE(verified.Pref,cfg.stopTime),'PAM3Study:Window');
for direction=[-1 1]
    c=cfg;c.referenceMode='stepQ';c.Qafter=80*direction;c.window=c.stepAnalysisWindow;
    qr=c.Qafter*(t>=c.stepTime);
    s=raw;s.Qref=signal(t,qr);s.P=s.Pref;s.Q=s.Qref;
    [s,~]=PAM3_LOG_COVERAGE(s,c,c.stopTime);
    o=PAM3_STAGE3_OBSERVATIONS(s,c);
    assert(o.ReferencesVerified && o.Q_Overshoot_var==0 && o.P_MaxAbsTrackingError_W==0);
    near=c.stepTime+[-.5;.5]*c.Ts;
    assert(isequal(PAM3_SAMPLE(s.Qref,near),[0;c.Qafter]));
    wrong=s;wrong.Qref.signals.values(:)=0;
    o=PAM3_STAGE3_OBSERVATIONS(wrong,c);assert(~o.ReferencesVerified);
end
bad=raw;bad.Pref=signal(t(1:end-1),400*ones(n-1,1));
expect_error(@()PAM3_LOG_COVERAGE(bad,cfg,cfg.stopTime),'PAM3Study:LogCoverage');
bad=raw;bad.Pref=signal(t(2:end),400*ones(n-1,1));
expect_error(@()PAM3_LOG_COVERAGE(bad,cfg,cfg.stopTime),'PAM3Study:LogCoverage');
keep=[1:100 102:n];bad=raw;bad.Pref=signal(t(keep),400*ones(numel(keep),1));
expect_error(@()PAM3_LOG_COVERAGE(bad,cfg,cfg.stopTime),'PAM3Study:LogCoverage');
bad=raw;bad.Pref=signal(0,400);
expect_error(@()PAM3_LOG_COVERAGE(bad,cfg,cfg.stopTime),'PAM3Study:LogCoverage');
expect_error(@()PAM3_LOG_COVERAGE(raw,cfg,.4),'PAM3Study:IncompleteSimulation');
% Inclusive final sample, roundoff at boundaries and duplicate event times.
last=signal([0;1;1;2],[10;20;21;30]);
assert(isequal(PAM3_SAMPLE(last,[0;.9;1;2+eps(2)]),[10;10;21;30]));
empty=signal([],[]);expect_error(@()PAM3_SAMPLE(empty,0),'PAM3Study:LogTime');
back=signal([0;2;1],[1;2;3]);expect_error(@()PAM3_SAMPLE(back,1),'PAM3Study:LogTime');
% Non-grid stop time: final hold may extend to StopTime, but no farther.
c=cfg;c.stopTime=cfg.stopTime+.25*cfg.Ts;
s=struct('Pref',signal([t;cfg.stopTime],400*ones(n+1,1)));
[s,~]=PAM3_LOG_COVERAGE(s,c,c.stopTime);
assert(PAM3_SAMPLE(s.Pref,c.stopTime)==400);
expect_error(@()PAM3_SAMPLE(s.Pref,c.stopTime+.1*c.Ts),'PAM3Study:Window');
fprintf('PASS: periodic log coverage, causal final hold, signed reference steps and missing-data rejection.\n');
end

function s=signal(t,x)
s=struct('time',t(:),'signals',struct('values',x));
end

function expect_error(action,id)
failed=false;
try
    action();
catch problem
    assert(strcmp(problem.identifier,id),'PAM3Study:Fixture', ...
        'Expected %s, got %s.',id,problem.identifier);
    failed=true;
end
assert(failed,'PAM3Study:Fixture','Expected error %s was not raised.',id);
end
