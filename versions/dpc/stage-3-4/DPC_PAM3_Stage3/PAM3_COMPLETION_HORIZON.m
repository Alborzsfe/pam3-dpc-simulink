function [horizon,evidence]=PAM3_COMPLETION_HORIZON(metadata,cfg)
% Release-independent completion check. No dependency on StopEventTime.
% ReachedStopTime confirms the configured horizon; periodic log coverage
% must still be checked independently by PAM3_LOG_COVERAGE.
validateattributes(cfg.stopTime,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.Ts,{'numeric'},{'scalar','real','finite','positive'});
assert(has_member(metadata,'ExecutionInfo'),'PAM3Study:CompletionMetadata', ...
    'Simulation metadata has no ExecutionInfo.');
execution=metadata.ExecutionInfo;
assert(isstruct(execution) && isscalar(execution) && isfield(execution,'StopEvent'), ...
    'PAM3Study:CompletionMetadata','ExecutionInfo has no StopEvent.');
reason=execution.StopEvent;
assert(ischar(reason) || (isstring(reason) && isscalar(reason)), ...
    'PAM3Study:CompletionMetadata','StopEvent must be text.');
reason=char(reason);
assert(strcmp(reason,'ReachedStopTime'),'PAM3Study:IncompleteSimulation', ...
    'Simulation did not reach StopTime: %s.',reason);

horizon=double(cfg.stopTime);
reported=NaN;source='ReachedStopTime + configured StopTime';
if isfield(execution,'StopEventTime') && ~isempty(execution.StopEventTime)
    reported=execution.StopEventTime;source='ExecutionInfo.StopEventTime';
elseif has_member(metadata,'ModelInfo')
    info=metadata.ModelInfo;
    if isstruct(info) && isscalar(info) && isfield(info,'StopTime') && ~isempty(info.StopTime)
        reported=info.StopTime;source='ModelInfo.StopTime';
    end
end
if ~strcmp(source,'ReachedStopTime + configured StopTime')
    assert(isnumeric(reported) && isreal(reported) && isscalar(reported) && isfinite(reported), ...
        'PAM3Study:CompletionMetadata','%s must be a finite scalar time.',source);
    reported=double(reported);
    tol=min(cfg.Ts/1e6,64*eps(max(1,abs(horizon))));
    % Metadata may identify the final executed hit rather than the right
    % endpoint of its held interval. Reject earlier stops or future times.
    assert(reported<=horizon+tol && reported+cfg.Ts>=horizon-tol, ...
        'PAM3Study:IncompleteSimulation', ...
        '%s is %.17g s; expected completion at %.17g s (period %.17g s).', ...
        source,reported,horizon,cfg.Ts);
end
evidence=struct('StopEvent',reason,'Horizon_s',horizon, ...
    'TimeSource',source,'ReportedStopTime_s',reported);
end

function yes=has_member(value,name)
yes=(isstruct(value) && isscalar(value) && isfield(value,name)) || ...
    (isobject(value) && isscalar(value) && isprop(value,name));
end
