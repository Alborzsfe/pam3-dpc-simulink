function VALIDATE_PAM3_COMPLETION()
% Pure MATLAB regression for metadata with and without StopEventTime.
cfg=struct('Ts',1/40000,'stopTime',.5);
old=struct('ExecutionInfo',struct('StopEvent','ReachedStopTime'));
[h,e]=PAM3_COMPLETION_HORIZON(old,cfg);
assert(h==cfg.stopTime && isnan(e.ReportedStopTime_s));
assert(strcmp(e.TimeSource,'ReachedStopTime + configured StopTime'));
legacy=old;legacy.ModelInfo=struct('StopTime',cfg.stopTime);
[h,e]=PAM3_COMPLETION_HORIZON(legacy,cfg);
assert(h==cfg.stopTime && e.ReportedStopTime_s==h && strcmp(e.TimeSource,'ModelInfo.StopTime'));
modern=old;modern.ExecutionInfo.StopEventTime=cfg.stopTime;
[h,e]=PAM3_COMPLETION_HORIZON(modern,cfg);
assert(h==cfg.stopTime && e.ReportedStopTime_s==h && strcmp(e.TimeSource,'ExecutionInfo.StopEventTime'));
modern.ExecutionInfo.StopEventTime=cfg.stopTime-cfg.Ts;
[h,e]=PAM3_COMPLETION_HORIZON(modern,cfg);
assert(h==cfg.stopTime && e.ReportedStopTime_s==cfg.stopTime-cfg.Ts);
empty=legacy;empty.ExecutionInfo.StopEventTime=[];
[h,e]=PAM3_COMPLETION_HORIZON(empty,cfg);
assert(h==cfg.stopTime && strcmp(e.TimeSource,'ModelInfo.StopTime'));
% Never replace an early/manual/failed stop with the configured end time.
for key={'ModelStop','StopCommand','DiagnosticError','KeyboardControlC','PauseCommand','TimeOut'}
    bad=modern;bad.ExecutionInfo.StopEvent=key{1};
    expect_error(@()PAM3_COMPLETION_HORIZON(bad,cfg),'PAM3Study:IncompleteSimulation');
end
bad=modern;bad.ExecutionInfo.StopEventTime=.4;
expect_error(@()PAM3_COMPLETION_HORIZON(bad,cfg),'PAM3Study:IncompleteSimulation');
bad=legacy;bad.ModelInfo.StopTime=.4;
expect_error(@()PAM3_COMPLETION_HORIZON(bad,cfg),'PAM3Study:IncompleteSimulation');
bad=modern;bad.ExecutionInfo.StopEventTime=.51;
expect_error(@()PAM3_COMPLETION_HORIZON(bad,cfg),'PAM3Study:IncompleteSimulation');
bad=modern;bad.ExecutionInfo.StopEventTime=NaN;
expect_error(@()PAM3_COMPLETION_HORIZON(bad,cfg),'PAM3Study:CompletionMetadata');
expect_error(@()PAM3_COMPLETION_HORIZON(struct(),cfg),'PAM3Study:CompletionMetadata');
% Missing metadata clock does not allow a truncated signal to pass coverage.
n=round(cfg.stopTime/cfg.Ts);t=(0:n-2)'*cfg.Ts;
raw=struct('Pref',struct('time',t,'signals',struct('values',400*ones(size(t)))));
h=PAM3_COMPLETION_HORIZON(old,cfg);
expect_error(@()PAM3_LOG_COVERAGE(raw,cfg,h),'PAM3Study:LogCoverage');
fprintf('PASS: legacy/current completion metadata; early stops and truncated logs rejected.\n');
end

function expect_error(action,id)
failed=false;
try
    action();
catch problem
    assert(strcmp(problem.identifier,id),'PAM3Study:CompletionFixture', ...
        'Expected %s, got %s.',id,problem.identifier);
    failed=true;
end
assert(failed,'PAM3Study:CompletionFixture','Expected error %s was not raised.',id);
end
