function report = dpc3_verify_binary_limit(baseline,limit,cfg,fs,report_folder)
% Actual full-plant equivalence: gates must be BIT-EXACT, not just similar THD.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 5, report_folder = fullfile(root,'validation'); end
if ~exist(report_folder,'dir'), mkdir(report_folder); end
tg = (0:round(cfg.stop_time/cfg.plant_step))'*cfg.plant_step;
g0 = quality_log_to_grid(baseline.gates,tg,'baseline gates');
g1 = quality_log_to_grid(limit.gates,tg,'binary-limit gates');
gate_mismatches = sum(g0(:) ~= g1(:));
tm = (0:round(cfg.stop_time/cfg.measurement_step))'*cfg.measurement_step;
names = {'iabc','vabc','vdc','p','pref','q','qref'};max_relative_error = 0;
if isfield(baseline,'v_feedback')
    names = [names,{'v_feedback','p_feedback','q_feedback'}];
end
signal_errors = zeros(1,numel(names));
for k = 1:numel(names)
    a = quality_log_to_grid(baseline.(names{k}),tm,names{k});
    b = quality_log_to_grid(limit.(names{k}),tm,names{k});
    signal_errors(k) = max(abs(a(:)-b(:)))/max(1,max(abs(a(:))));
    max_relative_error = max(max_relative_error,signal_errors(k));
end
passed = gate_mismatches == 0 && max_relative_error <= cfg.bypass_signal_relative_tolerance;
report = struct('passed',passed,'simulink_executed',true,'converter_executed',true, ...
    'control_hz',fs,'gate_values_compared',numel(g0),'gate_mismatches',gate_mismatches, ...
    'physical_signal_names',{names},'physical_relative_errors',signal_errors, ...
    'max_physical_relative_error',max_relative_error,'runtime',version);
save(fullfile(report_folder,sprintf('binary_limit_%gk.mat',fs/1000)),'report','-v7');
assert(passed,'DPC3:BinaryLimitPlant', ...
    'STOP: binary limit not equivalent: %d gate mismatches, max relative physical error %.4g.', ...
    gate_mismatches,max_relative_error);
fprintf('PASS actual full-plant binary limit: %g kHz, %d identical gate values, max physical relative error %.4g.\n', ...
    fs/1000,numel(g0),max_relative_error);
end
